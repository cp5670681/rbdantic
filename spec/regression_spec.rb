# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Regression coverage" do
  describe "copy/update metadata preservation" do
    it "preserves unset/default tracking across copy and update" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :name, String, default: "Jane"
        field :age, Integer, default: 18
        field :nickname, String, optional: true
      end

      original = klass.new
      copied = original.copy
      updated = original.update(nickname: "JJ")

      expect(original.model_fields_set).to eq(Set[])
      expect(copied.model_fields_set).to eq(Set[])
      expect(copied.model_dump(exclude_unset: true)).to eq({})

      expect(updated.model_fields_set).to eq(Set[:nickname])
      expect(updated.model_dump(exclude_unset: true)).to eq({ nickname: "JJ" })
    end
  end

  describe "wrap field validators" do
    it "receives the inner handler and can transform the validated value" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :count, Integer

        field_validator :count, mode: :wrap do |value, _ctx, handler|
          errors, validated = handler.call(value)
          raise errors.first.msg if errors.any?

          validated + 1
        end
      end

      model = klass.new(count: "4")
      expect(model.count).to eq(5)
    end

    it "chains multiple wrap validators in declaration order" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :count, Integer

        field_validator :count, mode: :wrap do |value, _ctx, handler|
          errors, validated = handler.call(value)
          raise errors.first.msg if errors.any?

          validated + 1
        end

        field_validator :count, mode: :wrap do |value, _ctx, handler|
          errors, validated = handler.call(value)
          raise errors.first.msg if errors.any?

          validated * 2
        end
      end

      expect(klass.new(count: "4").count).to eq(10)
    end
  end

  describe "plain field validators" do
    it "chains multiple plain validators in declaration order" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :count, Integer

        field_validator :count, mode: :plain do |value, _ctx|
          value.to_i + 1
        end

        field_validator :count, mode: :plain do |value, _ctx|
          value * 2
        end
      end

      expect(klass.new(count: "4").count).to eq(10)
    end
  end

  describe "nested model instance validation" do
    it "preserves optional nil fields when validating an existing nested model instance" do
      child_class = Class.new(Rbdantic::BaseModel) do
        field :name, String, optional: true
      end

      parent_class = Class.new(Rbdantic::BaseModel) do
        field :child, child_class
      end

      child = child_class.new
      expect(parent_class.new(child: child).child.name).to be_nil
    end

    it "re-runs field validators for existing nested model instances" do
      child_class = Class.new(Rbdantic::BaseModel) do
        field :email, String
        model_config validate_assignment: false

        field_validator :email do |value, _ctx|
          raise "Email must contain @" unless value.include?("@")
        end
      end

      parent_class = Class.new(Rbdantic::BaseModel) do
        field :child, child_class
      end

      child = child_class.new(email: "valid@example.com")
      child.email = "broken"

      expect {
        parent_class.new(child: child)
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.loc).to eq([:child, :email])
        expect(error.errors.first.msg).to eq("Email must contain @")
      end
    end
  end

  describe "alias support" do
    it "accepts aliased input keys and can emit schema properties by alias" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :user_id, Integer, alias_name: :userId
      end

      model = klass.new(userId: "7")

      expect(model.user_id).to eq(7)
      expect(model.model_dump(by_alias: true)).to eq(userId: 7)
      expect(klass.model_json_schema(by_alias: true)["properties"]).to have_key("userId")
    end

    it "supports include and exclude filters using aliases when by_alias is enabled" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :user_id, Integer, alias_name: :userId
        field :role, String
      end

      model = klass.new(userId: "7", role: "admin")

      expect(model.model_dump(by_alias: true, include: [:userId])).to eq(userId: 7)
      expect(model.model_dump(by_alias: true, exclude: [:userId])).to eq(role: "admin")
    end
  end

  describe "type and constraint fail-fast behavior" do
    it "supports Time fields with coercion and schema generation" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :created_at, Time
      end

      model = klass.new(created_at: "2024-01-02T03:04:05Z")

      expect(model.created_at).to be_a(Time)
      expect(klass.model_json_schema["properties"]["created_at"]).to include(
        "type" => "string",
        "format" => "date-time"
      )
    end

    it "rejects unsupported field types at definition time" do
      expect {
        Class.new(Rbdantic::BaseModel) do
          field :payload, Object
        end
      }.to raise_error(ArgumentError, /Unsupported field type/)
    end

    it "rejects unknown field constraints at definition time" do
      expect {
        Class.new(Rbdantic::BaseModel) do
          field :name, String, made_up: true
        end
      }.to raise_error(ArgumentError, /Unknown constraint/)
    end

    it "rejects unknown string formats at definition time" do
      expect {
        Class.new(Rbdantic::BaseModel) do
          field :slug, String, format: :slug
        end
      }.to raise_error(ArgumentError, /Unsupported format/)
    end

    it "rejects zero multiple_of values at definition time" do
      expect {
        Class.new(Rbdantic::BaseModel) do
          field :count, Integer, multiple_of: 0
        end
      }.to raise_error(ArgumentError, /multiple_of/)
    end
  end

  describe "coerce_mode compatibility" do
    it "accepts coerce_mode: :strict as a strictness alias" do
      klass = Class.new(Rbdantic::BaseModel) do
        model_config coerce_mode: :strict
        field :count, Integer
      end

      expect {
        klass.new(count: "1")
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.type).to eq(:type_error)
      end
    end
  end
end
