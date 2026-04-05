# frozen_string_literal: true

require "rbdantic"

RSpec.describe "Validator DSL" do
  # Reset test classes between tests to avoid pollution
  before(:each) do
    # Define classes fresh in each test to avoid inheritance issues
  end

  describe "field_validator" do
    describe "basic usage" do
      it "validates field value with custom logic" do
        class AgeModel < Rbdantic::BaseModel
          field :age, Integer

          field_validator :age do |value, ctx|
            raise "Age must be at least 18" if value < 18
          end
        end

        expect {
          AgeModel.new(age: 15)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.msg).to eq("Age must be at least 18")
          expect(e.errors.first.loc).to eq([:age])
        end

        model = AgeModel.new(age: 25)
        expect(model.age).to eq(25)
      end

      it "collects errors from multiple validators on same field" do
        class MultiValidatorModel < Rbdantic::BaseModel
          field :password, String

          field_validator :password do |value, ctx|
            raise "Must be at least 8 chars" if value.length < 8
          end

          field_validator :password do |value, ctx|
            raise "Must contain uppercase" unless value.match?(/[A-Z]/)
          end
        end

        expect {
          MultiValidatorModel.new(password: "short")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.length).to eq(2)
          expect(e.errors.map(&:msg)).to contain_exactly(
            "Must be at least 8 chars",
            "Must contain uppercase"
          )
        end
      end

      it "provides context with field info" do
        context_data = nil
        class ContextModel < Rbdantic::BaseModel
          field :value, Integer

          field_validator :value do |value, ctx|
            # Store context for verification outside
            Thread.current[:validator_context] = {
              field_name: ctx.field_name,
              field_info_type: ctx.field_info.type,
              model_class: ctx.model_class
            }
            true
          end
        end

        model = ContextModel.new(value: 10)
        context_data = Thread.current[:validator_context]
        Thread.current[:validator_context] = nil

        expect(context_data[:field_name]).to eq(:value)
        expect(context_data[:field_info_type]).to eq(Integer)
        expect(context_data[:model_class]).to eq(ContextModel)
        expect(model.value).to eq(10)
      end

      it "preserves false values when reading sibling fields from context" do
        seen = nil

        klass = Class.new(Rbdantic::BaseModel) do
          field :flag, Rbdantic::Boolean
          field :name, String

          field_validator :name, mode: :before do |value, ctx|
            seen = ctx.field_value(:flag)
            value
          end
        end

        klass.new(flag: false, name: "test")
        expect(seen).to be(false)
      end
    end

    describe "mode options" do
      it ":after mode runs after type/constraint validation" do
        class AfterModeModel < Rbdantic::BaseModel
          field :count, Integer, gt: 0

          field_validator :count, mode: :after do |value, ctx|
            raise "Must be even" if value % 2 != 0
          end
        end

        # Constraint error (gt: 0) should be caught first
        expect {
          AfterModeModel.new(count: -1)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          # Should have constraint error, not validator error
          expect(e.errors.first.type).to eq(:value_not_greater_than)
        end

        # Validator error for odd number
        expect {
          AfterModeModel.new(count: 3)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.msg).to eq("Must be even")
        end

        model = AfterModeModel.new(count: 4)
        expect(model.count).to eq(4)
      end

      it ":before mode runs before type coercion and validation" do
        seen_class = nil

        klass = Class.new(Rbdantic::BaseModel) do
          field :count, Integer

          field_validator :count, mode: :before do |value, ctx|
            seen_class = value.class
            value
          end
        end

        model = klass.new(count: "4")
        expect(seen_class).to eq(String)
        expect(model.count).to eq(4)
      end

      it ":plain mode runs validator only (no type/constraint check)" do
        class PlainModeModel < Rbdantic::BaseModel
          field :data, Integer, gt: 10

          field_validator :data, mode: :plain do |value, ctx|
            raise "Data must be a string" unless value.is_a?(String)
            1
          end
        end

        expect {
          PlainModeModel.new(data: 1)
        }.to raise_error(Rbdantic::ValidationError)

        model = PlainModeModel.new(data: "string")
        expect(model.data).to eq(1)
      end

      it ":plain mode short-circuits later field validators" do
        seen = []

        klass = Class.new(Rbdantic::BaseModel) do
          field :data, Integer

          field_validator :data, mode: :plain do |value, ctx|
            seen << :plain
            1
          end

          field_validator :data, mode: :after do |value, ctx|
            seen << :after
            raise "after should not run"
          end
        end

        model = klass.new(data: "anything")
        expect(model.data).to eq(1)
        expect(seen).to eq([:plain])
      end
    end

    describe "error collection" do
      it "adds errors to ValidationError.errors array" do
        class ErrorCollectionModel < Rbdantic::BaseModel
          field :email, String

          field_validator :email do |value, ctx|
            raise "Invalid email format" unless value.include?("@")
          end
        end

        expect {
          ErrorCollectionModel.new(email: "invalid")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors).to be_an(Array)
          expect(e.errors.first).to be_a(Rbdantic::ErrorDetail)
          expect(e.errors.first.type).to eq(:validation_failed)
          expect(e.errors.first.loc).to eq([:email])
          expect(e.errors.first.msg).to eq("Invalid email format")
          expect(e.errors.first.input).to eq("invalid")
        end
      end
    end
  end

  describe "model_validator" do
    describe ":before mode (data preprocessing)" do
      it "transforms input data before field validation" do
        class PreprocessModel < Rbdantic::BaseModel
          field :email, String

          model_validator mode: :before do |data|
            data[:email] = data[:email]&.downcase&.strip
            data
          end
        end

        model = PreprocessModel.new(email: "  TEST@EXAMPLE.COM  ")
        expect(model.email).to eq("test@example.com")
      end

      it "runs before any field validation" do
        class BeforeValidationModel < Rbdantic::BaseModel
          field :value, Integer

          model_validator mode: :before do |data|
            data[:value] = data[:value].to_s.to_i if data[:value].is_a?(String)
            data
          end
        end

        # String gets converted to integer before type check
        model = BeforeValidationModel.new(value: "42")
        expect(model.value).to eq(42)
      end

      it "collects errors from before validators" do
        class BeforeErrorModel < Rbdantic::BaseModel
          field :name, String

          model_validator mode: :before do |data|
            raise "Name cannot be empty" if data[:name].nil? || data[:name].empty?
            data
          end
        end

        expect {
          BeforeErrorModel.new(name: "")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.msg).to eq("Name cannot be empty")
        end
      end

      it "raises ValidationError when before validator returns non-hash data" do
        klass = Class.new(Rbdantic::BaseModel) do
          field :name, String

          model_validator mode: :before do |data|
            nil
          end
        end

        expect {
          klass.new(name: "test")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:model_validation_failed)
        end
      end
    end

    describe ":after mode (whole model validation)" do
      it "validates the complete model instance" do
        class AfterValidationModel < Rbdantic::BaseModel
          field :start_date, String
          field :end_date, String

          model_validator mode: :after do |model|
            raise "End date must be after start date" if model.end_date < model.start_date
          end
        end

        expect {
          AfterValidationModel.new(start_date: "2024-12", end_date: "2024-01")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.msg).to eq("End date must be after start date")
        end

        model = AfterValidationModel.new(start_date: "2024-01", end_date: "2024-12")
        expect(model.start_date).to eq("2024-01")
      end

      it "runs after all fields are validated and set" do
        class CrossFieldModel < Rbdantic::BaseModel
          field :password, String, min_length: 8
          field :confirm_password, String

          model_validator mode: :after do |model|
            raise "Passwords must match" unless model.password == model.confirm_password
          end
        end

        # Field constraint error (min_length) should be caught first
        expect {
          CrossFieldModel.new(password: "short", confirm_password: "short")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:string_too_short)
        end

        # Cross-field validation error
        expect {
          CrossFieldModel.new(password: "longpassword", confirm_password: "different")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.msg).to eq("Passwords must match")
        end

        model = CrossFieldModel.new(password: "longpassword", confirm_password: "longpassword")
        expect(model.password).to eq("longpassword")
      end

      it "can access other fields via model instance" do
        class DependentFieldsModel < Rbdantic::BaseModel
          field :min, Integer
          field :max, Integer

          model_validator mode: :after do |model|
            raise "Max must be greater than min" unless model.max > model.min
          end
        end

        expect {
          DependentFieldsModel.new(min: 100, max: 50)
        }.to raise_error(Rbdantic::ValidationError)

        model = DependentFieldsModel.new(min: 10, max: 100)
        expect(model.min).to eq(10)
        expect(model.max).to eq(100)
      end
    end
  end

  describe "validator combination" do
    it "combines field_validator and model_validator" do
      class CombinedModel < Rbdantic::BaseModel
        field :age, Integer, gt: 0
        field :category, String

        field_validator :age do |value, ctx|
          raise "Age must be under 100" if value >= 100
        end

        model_validator mode: :before do |data|
          data[:category] = data[:category]&.upcase
          data
        end

        model_validator mode: :after do |model|
          raise "Category must be ADULT for age >= 18" if model.age >= 18 && model.category != "ADULT"
        end
      end

      # Valid case
      model = CombinedModel.new(age: 25, category: "adult")
      expect(model.age).to eq(25)
      expect(model.category).to eq("ADULT")

      # Field validator error
      expect {
        CombinedModel.new(age: 150, category: "adult")
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.first.msg).to eq("Age must be under 100")
      end

      # Model validator after error
      expect {
        CombinedModel.new(age: 25, category: "child")
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.first.msg).to eq("Category must be ADULT for age >= 18")
      end
    end

    it "runs validators in correct order" do
      # Use thread-local to track execution order across closures
      Thread.current[:execution_order] = []

      class OrderTrackingModel < Rbdantic::BaseModel
        field :value, Integer
        field :processed_by, String

        model_validator mode: :before do |data|
          Thread.current[:execution_order] << :before_validator
          data[:processed_by] = "before"
          data
        end

        field_validator :value do |value, ctx|
          Thread.current[:execution_order] << :value_field_validator
          true
        end

        field_validator :processed_by do |value, ctx|
          Thread.current[:execution_order] << :processed_by_field_validator
          true
        end

        model_validator mode: :after do |model|
          Thread.current[:execution_order] << :after_validator
        end
      end

      model = OrderTrackingModel.new(value: 10, processed_by: "initial")
      order = Thread.current[:execution_order]
      Thread.current[:execution_order] = nil

      # Order: before -> value field_validator -> processed_by field_validator -> after
      expect(order).to eq([
        :before_validator,
        :value_field_validator,
        :processed_by_field_validator,
        :after_validator
      ])
      expect(model.processed_by).to eq("before")  # Modified by before validator
    end
  end

  describe "validator inheritance" do
    it "inherits field_validators from parent class" do
      class ParentWithFieldValidator < Rbdantic::BaseModel
        field :age, Integer

        field_validator :age do |value, ctx|
          raise "Age must be positive" if value <= 0
        end
      end

      class ChildWithInheritedValidator < ParentWithFieldValidator
        field :name, String
      end

      # Child should have parent's validator
      expect {
        ChildWithInheritedValidator.new(age: -5, name: "test")
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.first.msg).to eq("Age must be positive")
      end

      model = ChildWithInheritedValidator.new(age: 25, name: "test")
      expect(model.age).to eq(25)
      expect(model.name).to eq("test")
    end

    it "inherits model_validators from parent class" do
      class ParentWithModelValidator < Rbdantic::BaseModel
        field :email, String

        model_validator mode: :before do |data|
          data[:email] = data[:email]&.downcase
          data
        end
      end

      class ChildWithInheritedModelValidator < ParentWithModelValidator
        field :name, String
      end

      model = ChildWithInheritedModelValidator.new(email: "TEST@EXAMPLE.COM", name: "Test")
      expect(model.email).to eq("test@example.com")
    end

    it "allows child to add additional validators" do
      class ParentBase < Rbdantic::BaseModel
        field :value, Integer

        field_validator :value do |value, ctx|
          raise "Must be positive" if value <= 0
        end
      end

      class ChildWithExtraValidator < ParentBase
        field_validator :value do |value, ctx|
          raise "Must be even" if value % 2 != 0
        end
      end

      # Should have both validators
      expect {
        ChildWithExtraValidator.new(value: -5)
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.map(&:msg)).to include("Must be positive")
      end

      expect {
        ChildWithExtraValidator.new(value: 3)
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.map(&:msg)).to include("Must be even")
      end

      model = ChildWithExtraValidator.new(value: 4)
      expect(model.value).to eq(4)
    end

    it "parent validators do not affect sibling classes" do
      class FirstSibling < Rbdantic::BaseModel
        field :x, Integer

        field_validator :x do |value, ctx|
          raise "First sibling error" if value < 0
        end
      end

      class SecondSibling < Rbdantic::BaseModel
        field :x, Integer
      end

      # First sibling has validator
      expect {
        FirstSibling.new(x: -1)
      }.to raise_error(Rbdantic::ValidationError)

      # Second sibling does not
      model = SecondSibling.new(x: -1)
      expect(model.x).to eq(-1)
    end
  end
end
