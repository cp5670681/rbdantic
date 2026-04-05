# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rbdantic::BaseModel do
  describe "field definition" do
    it "defines fields with field DSL method" do
      class TestModel1 < Rbdantic::BaseModel
        field :name, String
        field :age, Integer
      end

      expect(TestModel1.fields.keys).to contain_exactly(:name, :age)
      expect(TestModel1.fields[:name].type).to eq(String)
      expect(TestModel1.fields[:age].type).to eq(Integer)
    end

    it "creates getter methods for fields" do
      class TestModel2 < Rbdantic::BaseModel
        field :name, String
      end

      model = TestModel2.new(name: "test")
      expect(model.name).to eq("test")
    end

    it "creates setter methods for fields" do
      class TestModel3 < Rbdantic::BaseModel
        field :name, String
      end

      model = TestModel3.new(name: "test")
      model.name = "updated"
      expect(model.name).to eq("updated")
    end

    it "supports bracket access for field values" do
      class TestModel4 < Rbdantic::BaseModel
        field :name, String
      end

      model = TestModel4.new(name: "test")
      expect(model[:name]).to eq("test")
      model[:name] = "updated"
      expect(model[:name]).to eq("updated")
    end
  end

  describe "default values" do
    it "supports static default values" do
      class TestModel5 < Rbdantic::BaseModel
        field :name, String, default: "unknown"
        field :count, Integer, default: 0
      end

      model = TestModel5.new(name: "custom")
      expect(model.name).to eq("custom")
      expect(model.count).to eq(0)
    end

    it "supports default_factory for dynamic defaults" do
      class TestModel6 < Rbdantic::BaseModel
        field :items, Array, default_factory: -> { [] }
        field :timestamp, Float, default_factory: -> { Time.now.to_f }
      end

      model1 = TestModel6.new
      model2 = TestModel6.new

      expect(model1.items).to eq([])
      # default_factory creates new instances each time
      expect(model1.items.object_id).not_to eq(model2.items.object_id)
      expect(model1.timestamp).to be_a(Float)
    end

    it "uses default when field not provided" do
      class TestModel7 < Rbdantic::BaseModel
        field :name, String, default: "default_name"
        field :required_field, String
      end

      model = TestModel7.new(required_field: "value")
      expect(model.name).to eq("default_name")
    end

    it "supports nil as an explicit default value" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :nickname, String, default: nil
      end

      model = klass.new
      expect(model.nickname).to be_nil
      expect(model.model_dump).to eq({ nickname: nil })
    end

    it "does not replace an explicit nil with the default value" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :count, Integer, optional: true, default: 5
      end

      model = klass.new(count: nil)

      expect(model.count).to be_nil
      expect(model.model_dump(exclude_unset: true)).to eq({ count: nil })
    end
  end

  describe "optional fields" do
    it "allows optional fields to be omitted" do
      class TestModel8 < Rbdantic::BaseModel
        field :name, String
        field :nickname, String, optional: true
      end

      model = TestModel8.new(name: "John")
      expect(model.name).to eq("John")
      expect(model.nickname).to be_nil
    end

    it "raises error for missing required fields without default" do
      class TestModel9 < Rbdantic::BaseModel
        field :name, String
      end

      expect {
        TestModel9.new
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.type).to eq(:value_missing)
        expect(error.errors.first.loc).to eq([:name])
      end
    end
  end

  describe "model_config" do
    describe "extra: :forbid" do
      it "raises error for extra fields" do
        class TestModel10 < Rbdantic::BaseModel
          field :name, String
          model_config extra: :forbid
        end

        expect {
          TestModel10.new(name: "test", extra_field: "value")
        }.to raise_error(Rbdantic::ValidationError) do |error|
          expect(error.errors.first.type).to eq(:extra_field_forbidden)
          expect(error.errors.first.msg).to include("extra_field")
        end
      end
    end

    describe "extra: :allow" do
      it "accepts and stores extra fields" do
        class TestModel11 < Rbdantic::BaseModel
          field :name, String
          model_config extra: :allow
        end

        model = TestModel11.new(name: "test", extra_field: "value")
        expect(model.name).to eq("test")
        expect(model[:extra_field]).to eq("value")
      end
    end

    describe "extra: :ignore" do
      it "silently ignores extra fields" do
        class TestModel12 < Rbdantic::BaseModel
          field :name, String
          model_config extra: :ignore
        end

        model = TestModel12.new(name: "test", extra_field: "value")
        expect(model.name).to eq("test")
        expect(model[:extra_field]).to be_nil
      end
    end

    describe "frozen: true" do
      it "prevents modification after initialization" do
        class TestModel13 < Rbdantic::BaseModel
          field :name, String
          model_config frozen: true
        end

        model = TestModel13.new(name: "test")
        expect(model).to be_frozen

        expect {
          model.name = "updated"
        }.to raise_error(FrozenError)

        expect {
          model[:name] = "updated"
        }.to raise_error(FrozenError)
      end
    end

    describe "strict: true" do
      it "raises error for type mismatches without coercion" do
        class TestModel14 < Rbdantic::BaseModel
          field :count, Integer
          model_config strict: true
        end

        expect {
          TestModel14.new(count: "123")
        }.to raise_error(Rbdantic::ValidationError) do |error|
          expect(error.errors.first.type).to eq(:type_error)
        end
      end
    end

    describe "strict: false (default)" do
      it "coerces values to target type" do
        class TestModel15 < Rbdantic::BaseModel
          field :count, Integer
        end

        model = TestModel15.new(count: "123")
        expect(model.count).to eq(123)
        expect(model.count).to be_a(Integer)
      end
    end

    describe "validate_assignment: true" do
      it "validates assignments through setters" do
        class TestModel15a < Rbdantic::BaseModel
          field :count, Integer
          model_config validate_assignment: true, strict: true
        end

        model = TestModel15a.new(count: 1)

        expect {
          model.count = "bad"
        }.to raise_error(Rbdantic::ValidationError) do |error|
          expect(error.errors.first.type).to eq(:type_error)
        end

        expect(model.count).to eq(1)
      end

      it "validates assignments through bracket writers" do
        class TestModel15b < Rbdantic::BaseModel
          field :count, Integer
          model_config validate_assignment: true, strict: true
        end

        model = TestModel15b.new(count: 1)

        expect {
          model[:count] = "bad"
        }.to raise_error(Rbdantic::ValidationError)

        expect(model.count).to eq(1)
      end
    end
  end

  describe "custom validators" do
    it "supports Proc validators that return false on failure" do
      class TestModel16 < Rbdantic::BaseModel
        field :email, String, validators: [->(v) { v.include?("@") || false }]
      end

      expect {
        TestModel16.new(email: "noemail")
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.type).to eq(:validation_failed)
      end

      model = TestModel16.new(email: "test@example.com")
      expect(model.email).to eq("test@example.com")
    end

    it "supports Proc validators that return error message" do
      class TestModel17 < Rbdantic::BaseModel
        field :password, String, validators: [->(v) { v.length >= 8 ? nil : "Password too short" }]
      end

      expect {
        TestModel17.new(password: "short")
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.msg).to eq("Password too short")
      end
    end
  end

  describe "FieldInfo" do
    it "stores field metadata correctly" do
      class TestModel18 < Rbdantic::BaseModel
        field :name, String, min_length: 5, max_length: 100
      end

      field_info = TestModel18.fields[:name]
      expect(field_info.name).to eq(:name)
      expect(field_info.type).to eq(String)
      expect(field_info.constraints).to eq({ min_length: 5, max_length: 100 })
    end

    it "identifies required fields correctly" do
      class TestModel19 < Rbdantic::BaseModel
        field :required, String
        field :with_default, String, default: "value"
        field :optional, String, optional: true
      end

      expect(TestModel19.fields[:required].required?).to be true
      expect(TestModel19.fields[:with_default].required?).to be false
      expect(TestModel19.fields[:optional].required?).to be false
    end

    it "identifies fields with defaults correctly" do
      class TestModel20 < Rbdantic::BaseModel
        field :no_default, String
        field :with_default, String, default: "value"
        field :with_factory, Array, default_factory: -> { [] }
      end

      expect(TestModel20.fields[:no_default].has_default?).to be false
      expect(TestModel20.fields[:with_default].has_default?).to be true
      expect(TestModel20.fields[:with_factory].has_default?).to be true
    end

    it "treats nil as a real default value" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :maybe_name, String, default: nil
      end

      expect(klass.fields[:maybe_name].has_default?).to be true
      expect(klass.fields[:maybe_name].required?).to be false
    end
  end
end
