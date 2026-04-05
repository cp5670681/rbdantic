# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Validation and Constraints" do
  describe Rbdantic::ValidationError do
    it "stores array of ErrorDetail objects" do
      class ValidationTestModel1 < Rbdantic::BaseModel
        field :name, String, min_length: 5
        field :age, Integer, gt: 0
      end

      begin
        ValidationTestModel1.new(name: "abc", age: -1)
      rescue Rbdantic::ValidationError => e
        expect(e.errors).to be_an(Array)
        expect(e.errors.length).to eq(2)
        expect(e.errors.first).to be_a(Rbdantic::ErrorDetail)
      end
    end

    it "provides error_count method" do
      class ValidationTestModel2 < Rbdantic::BaseModel
        field :f1, String, min_length: 10
        field :f2, String, min_length: 10
        field :f3, String, min_length: 10
      end

      begin
        ValidationTestModel2.new(f1: "a", f2: "b", f3: "c")
      rescue Rbdantic::ValidationError => e
        expect(e.error_count).to eq(3)
      end
    end

    it "formats readable error message" do
      class ValidationTestModel3 < Rbdantic::BaseModel
        field :name, String
      end

      begin
        ValidationTestModel3.new
      rescue Rbdantic::ValidationError => e
        expect(e.message).to include("1 validation error")
        expect(e.message).to include("name")
        expect(e.message).to include("required")
      end
    end

    it "serializes to JSON compatible hash" do
      class ValidationTestModel4 < Rbdantic::BaseModel
        field :value, Integer, gt: 10
      end

      begin
        ValidationTestModel4.new(value: 5)
      rescue Rbdantic::ValidationError => e
        json = e.as_json
        expect(json).to have_key(:errors)
        expect(json).to have_key(:error_count)
        expect(json[:error_count]).to eq(1)
      end
    end
  end

  describe Rbdantic::ErrorDetail do
    it "stores error type, location, message, and input" do
      error = Rbdantic::ErrorDetail.new(
        type: :string_too_short,
        loc: [:name],
        msg: "String must be at least 5 characters",
        input: "abc"
      )

      expect(error.type).to eq(:string_too_short)
      expect(error.loc).to eq([:name])
      expect(error.msg).to eq("String must be at least 5 characters")
      expect(error.input).to eq("abc")
    end

    it "converts to hash" do
      error = Rbdantic::ErrorDetail.new(
        type: :value_missing,
        loc: [:field],
        msg: "Field is required"
      )

      hash = error.to_h
      expect(hash[:type]).to eq(:value_missing)
      expect(hash[:loc]).to eq([:field])
      expect(hash[:msg]).to eq("Field is required")
      expect(hash[:input]).to be_nil
    end

    it "supports nested location paths" do
      error = Rbdantic::ErrorDetail.new(
        type: :type_error,
        loc: [:user, :address, :city],
        msg: "Expected String"
      )

      expect(error.loc).to eq([:user, :address, :city])
      expect(error.msg).to include("Expected String")
    end
  end

  describe "String constraints" do
    describe "format" do
      it "validates email format at runtime" do
        klass = Class.new(Rbdantic::BaseModel) do
          field :email, String, format: :email
        end

        expect(klass.new(email: "test@example.com").email).to eq("test@example.com")

        expect {
          klass.new(email: "not-an-email")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:string_format_mismatch)
        end
      end

      it "validates uuid format at runtime" do
        klass = Class.new(Rbdantic::BaseModel) do
          field :id, String, format: :uuid
        end

        expect {
          klass.new(id: "not-a-uuid")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:string_format_mismatch)
        end
      end
    end

    describe "min_length" do
      it "validates minimum string length" do
        class StringTest1 < Rbdantic::BaseModel
          field :name, String, min_length: 3
        end

        model = StringTest1.new(name: "abc")
        expect(model.name).to eq("abc")

        expect {
          StringTest1.new(name: "ab")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:string_too_short)
          expect(e.errors.first.msg).to include("at least 3 characters")
        end
      end
    end

    describe "max_length" do
      it "validates maximum string length" do
        class StringTest2 < Rbdantic::BaseModel
          field :code, String, max_length: 5
        end

        model = StringTest2.new(code: "abc")
        expect(model.code).to eq("abc")

        expect {
          StringTest2.new(code: "abcdefg")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:string_too_long)
          expect(e.errors.first.msg).to include("at most 5 characters")
        end
      end
    end

    describe "pattern" do
      it "validates string matches regex pattern" do
        class StringTest3 < Rbdantic::BaseModel
          field :email, String, pattern: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
        end

        model = StringTest3.new(email: "test@example.com")
        expect(model.email).to eq("test@example.com")

        expect {
          StringTest3.new(email: "invalid")
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:string_pattern_mismatch)
          expect(e.errors.first.msg).to include("pattern")
        end
      end

      it "validates alphanumeric pattern" do
        class StringTest4 < Rbdantic::BaseModel
          field :username, String, pattern: /\A[a-zA-Z0-9]+\z/
        end

        model = StringTest4.new(username: "User123")
        expect(model.username).to eq("User123")

        expect {
          StringTest4.new(username: "user_name")
        }.to raise_error(Rbdantic::ValidationError)
      end
    end

    describe "combined string constraints" do
      it "validates multiple constraints together" do
        class StringTest5 < Rbdantic::BaseModel
          field :password, String, min_length: 8, max_length: 64, pattern: /\A.*[A-Z].*\z/
        end

        model = StringTest5.new(password: "Password123")
        expect(model.password).to eq("Password123")

        # Too short
        expect {
          StringTest5.new(password: "Pass1")
        }.to raise_error(Rbdantic::ValidationError)

        # No uppercase
        expect {
          StringTest5.new(password: "password123")
        }.to raise_error(Rbdantic::ValidationError)
      end
    end
  end

  describe "Numeric constraints" do
    describe "gt (greater than)" do
      it "validates value is strictly greater than threshold" do
        class NumericTest1 < Rbdantic::BaseModel
          field :age, Integer, gt: 0
        end

        model = NumericTest1.new(age: 1)
        expect(model.age).to eq(1)

        expect {
          NumericTest1.new(age: 0)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:value_not_greater_than)
          expect(e.errors.first.msg).to include("greater than 0")
        end
      end
    end

    describe "ge (greater than or equal)" do
      it "validates value is greater than or equal to threshold" do
        class NumericTest2 < Rbdantic::BaseModel
          field :rating, Float, ge: 0.0
        end

        model = NumericTest2.new(rating: 0.0)
        expect(model.rating).to eq(0.0)

        model2 = NumericTest2.new(rating: 4.5)
        expect(model2.rating).to eq(4.5)

        expect {
          NumericTest2.new(rating: -0.1)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:value_not_greater_than_or_equal)
        end
      end
    end

    describe "lt (less than)" do
      it "validates value is strictly less than threshold" do
        class NumericTest3 < Rbdantic::BaseModel
          field :percentage, Float, lt: 100.0
        end

        model = NumericTest3.new(percentage: 99.9)
        expect(model.percentage).to eq(99.9)

        expect {
          NumericTest3.new(percentage: 100.0)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:value_not_less_than)
        end
      end
    end

    describe "le (less than or equal)" do
      it "validates value is less than or equal to threshold" do
        class NumericTest4 < Rbdantic::BaseModel
          field :score, Integer, le: 100
        end

        model = NumericTest4.new(score: 100)
        expect(model.score).to eq(100)

        model2 = NumericTest4.new(score: 50)
        expect(model2.score).to eq(50)

        expect {
          NumericTest4.new(score: 101)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:value_not_less_than_or_equal)
        end
      end
    end

    describe "multiple_of" do
      it "validates value is multiple of given number" do
        class NumericTest5 < Rbdantic::BaseModel
          field :batch_size, Integer, multiple_of: 10
        end

        model = NumericTest5.new(batch_size: 50)
        expect(model.batch_size).to eq(50)

        expect {
          NumericTest5.new(batch_size: 15)
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:value_not_multiple_of)
          expect(e.errors.first.msg).to include("multiple of 10")
        end
      end
    end

    describe "combined numeric constraints" do
      it "validates range constraints together" do
        class NumericTest6 < Rbdantic::BaseModel
          field :temperature, Float, ge: -50.0, le: 50.0
        end

        model = NumericTest6.new(temperature: 25.0)
        expect(model.temperature).to eq(25.0)

        expect {
          NumericTest6.new(temperature: -60.0)
        }.to raise_error(Rbdantic::ValidationError)

        expect {
          NumericTest6.new(temperature: 60.0)
        }.to raise_error(Rbdantic::ValidationError)
      end
    end
  end

  describe "Array constraints" do
    describe "min_items" do
      it "validates minimum array length" do
        class ArrayTest1 < Rbdantic::BaseModel
          field :items, Array, min_items: 2
        end

        model = ArrayTest1.new(items: [1, 2, 3])
        expect(model.items).to eq([1, 2, 3])

        expect {
          ArrayTest1.new(items: [1])
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:array_too_short)
          expect(e.errors.first.msg).to include("at least 2 items")
        end
      end
    end

    describe "max_items" do
      it "validates maximum array length" do
        class ArrayTest2 < Rbdantic::BaseModel
          field :tags, Array, max_items: 5
        end

        model = ArrayTest2.new(tags: [1, 2, 3])
        expect(model.tags).to eq([1, 2, 3])

        expect {
          ArrayTest2.new(tags: [1, 2, 3, 4, 5, 6])
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:array_too_long)
          expect(e.errors.first.msg).to include("at most 5 items")
        end
      end
    end

    describe "unique_items" do
      it "validates array items are unique" do
        class ArrayTest3 < Rbdantic::BaseModel
          field :ids, Array, unique_items: true
        end

        model = ArrayTest3.new(ids: [1, 2, 3])
        expect(model.ids).to eq([1, 2, 3])

        expect {
          ArrayTest3.new(ids: [1, 2, 2, 3])
        }.to raise_error(Rbdantic::ValidationError) do |e|
          expect(e.errors.first.type).to eq(:array_items_not_unique)
          expect(e.errors.first.msg).to include("unique")
        end
      end

      it "allows array with unique items" do
        class ArrayTest4 < Rbdantic::BaseModel
          field :codes, Array, unique_items: true
        end

        model = ArrayTest4.new(codes: ["a", "b", "c"])
        expect(model.codes).to eq(["a", "b", "c"])
      end
    end

    describe "combined array constraints" do
      it "validates multiple array constraints together" do
        class ArrayTest5 < Rbdantic::BaseModel
          field :choices, Array, min_items: 1, max_items: 3, unique_items: true
        end

        model = ArrayTest5.new(choices: ["a", "b"])
        expect(model.choices).to eq(["a", "b"])

        # Empty array fails min_items
        expect {
          ArrayTest5.new(choices: [])
        }.to raise_error(Rbdantic::ValidationError)

        # Duplicate fails unique_items
        expect {
          ArrayTest5.new(choices: ["a", "a"])
        }.to raise_error(Rbdantic::ValidationError)
      end
    end
  end

  describe "type validation" do
    it "validates String type" do
      class TypeTest1 < Rbdantic::BaseModel
        field :name, String
        model_config strict: true
      end

      model = TypeTest1.new(name: "test")
      expect(model.name).to eq("test")

      expect {
        TypeTest1.new(name: 123)
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.first.type).to eq(:type_error)
        expect(e.errors.first.msg).to include("Expected String")
      end
    end

    it "validates Integer type" do
      class TypeTest2 < Rbdantic::BaseModel
        field :count, Integer
        model_config strict: true
      end

      model = TypeTest2.new(count: 42)
      expect(model.count).to eq(42)

      expect {
        TypeTest2.new(count: "42")
      }.to raise_error(Rbdantic::ValidationError)
    end

    it "validates Float type" do
      class TypeTest3 < Rbdantic::BaseModel
        field :price, Float
        model_config strict: true
      end

      model = TypeTest3.new(price: 9.99)
      expect(model.price).to eq(9.99)

      expect {
        TypeTest3.new(price: "9.99")
      }.to raise_error(Rbdantic::ValidationError)
    end

    it "validates Array type" do
      class TypeTest4 < Rbdantic::BaseModel
        field :items, Array
        model_config strict: true
      end

      model = TypeTest4.new(items: [1, 2, 3])
      expect(model.items).to eq([1, 2, 3])

      expect {
        TypeTest4.new(items: "not an array")
      }.to raise_error(Rbdantic::ValidationError)
    end

    it "validates Hash type" do
      class TypeTest5 < Rbdantic::BaseModel
        field :data, Hash
        model_config strict: true
      end

      model = TypeTest5.new(data: { key: "value" })
      expect(model.data).to eq({ key: "value" })

      expect {
        TypeTest5.new(data: [1, 2])
      }.to raise_error(Rbdantic::ValidationError)
    end
  end

  describe "ModelConfig validation" do
    it "raises error for invalid extra value" do
      expect {
        Rbdantic::ModelConfig.new(extra: :invalid)
      }.to raise_error(ArgumentError) do |e|
        expect(e.message).to include("extra must be one of")
      end
    end

    it "accepts valid configuration options" do
      config = Rbdantic::ModelConfig.new(
        strict: true,
        extra: :forbid,
        frozen: true,
        validate_assignment: false
      )

      expect(config.strict).to be true
      expect(config.extra).to eq(:forbid)
      expect(config.frozen).to be true
      expect(config.validate_assignment).to be false
    end
  end
end
