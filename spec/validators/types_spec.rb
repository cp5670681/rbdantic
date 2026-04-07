# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rbdantic::Validators::Types::Base do
  let(:base_class) { Rbdantic::Validators::Types::Base }

  describe "#initialize" do
    it "stores constraints" do
      validator = base_class.new(min_length: 5, max_length: 10)
      expect(validator.constraints).to eq({ min_length: 5, max_length: 10 })
    end

    it "defaults to empty constraints" do
      validator = base_class.new
      expect(validator.constraints).to eq({})
    end
  end

  describe "#validate" do
    it "raises NotImplementedError" do
      validator = base_class.new
      expect { validator.validate("test") }.to raise_error(NotImplementedError)
    end
  end

  describe "#coerce" do
    it "returns nil by default" do
      validator = base_class.new
      expect(validator.coerce("test")).to be_nil
    end
  end

  describe "#error" do
    it "creates ErrorDetail" do
      validator = base_class.new
      err = validator.send(:error, type: :test_error, loc: ["field"], msg: "Test message", input: "value")
      expect(err).to be_a(Rbdantic::ErrorDetail)
      expect(err.type).to eq(:test_error)
      expect(err.loc).to eq(["field"])
      expect(err.msg).to eq("Test message")
      expect(err.input).to eq("value")
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::String do
  let(:validator_class) { Rbdantic::Validators::Types::String }

  describe "#validate" do
    context "with valid string" do
      it "returns no errors" do
        validator = validator_class.new
        errors, value = validator.validate("test", ["name"])
        expect(errors).to be_empty
        expect(value).to eq("test")
      end
    end

    context "with type coercion" do
      it "coerces Symbol to String" do
        validator = validator_class.new
        errors, value = validator.validate(:symbol, ["name"])
        expect(errors).to be_empty
        expect(value).to eq("symbol")
      end

      it "coerces Integer to String" do
        validator = validator_class.new
        errors, value = validator.validate(42, ["name"])
        expect(errors).to be_empty
        expect(value).to eq("42")
      end

      it "returns error for non-coercible types" do
        validator = validator_class.new
        errors, value = validator.validate([1, 2, 3], ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end

    context "with min_length constraint" do
      it "validates when length >= min_length" do
        validator = validator_class.new(min_length: 3)
        errors, _ = validator.validate("test", ["name"])
        expect(errors).to be_empty
      end

      it "errors when length < min_length" do
        validator = validator_class.new(min_length: 5)
        errors, _ = validator.validate("test", ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:string_too_short)
        expect(errors.first.msg).to include("at least 5 characters")
      end
    end

    context "with max_length constraint" do
      it "validates when length <= max_length" do
        validator = validator_class.new(max_length: 10)
        errors, _ = validator.validate("test", ["name"])
        expect(errors).to be_empty
      end

      it "errors when length > max_length" do
        validator = validator_class.new(max_length: 3)
        errors, _ = validator.validate("testing", ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:string_too_long)
        expect(errors.first.msg).to include("at most 3 characters")
      end
    end

    context "with pattern constraint" do
      it "validates when pattern matches" do
        validator = validator_class.new(pattern: /\A[a-z]+\z/)
        errors, _ = validator.validate("test", ["name"])
        expect(errors).to be_empty
      end

      it "errors when pattern does not match" do
        validator = validator_class.new(pattern: /\A[a-z]+\z/)
        errors, _ = validator.validate("Test123", ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:string_pattern_mismatch)
      end
    end

    context "with format constraint" do
      it "validates email format" do
        validator = validator_class.new(format: :email)
        errors, _ = validator.validate("test@example.com", ["name"])
        expect(errors).to be_empty
      end

      it "errors on invalid email" do
        validator = validator_class.new(format: :email)
        errors, _ = validator.validate("not-an-email", ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:string_format_mismatch)
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Integer do
  let(:validator_class) { Rbdantic::Validators::Types::Integer }

  describe "#validate" do
    context "with valid integer" do
      it "returns no errors" do
        validator = validator_class.new
        errors, value = validator.validate(42, ["age"])
        expect(errors).to be_empty
        expect(value).to eq(42)
      end
    end

    context "with type coercion" do
      it "coerces String to Integer" do
        validator = validator_class.new
        errors, value = validator.validate("42", ["age"])
        expect(errors).to be_empty
        expect(value).to eq(42)
      end

      it "coerces Float if integer value" do
        validator = validator_class.new
        errors, value = validator.validate(42.0, ["age"])
        expect(errors).to be_empty
        expect(value).to eq(42)
      end

      it "errors on Float with decimal" do
        validator = validator_class.new
        errors, _ = validator.validate(42.5, ["age"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end

    context "with gt constraint" do
      it "validates when value > gt" do
        validator = validator_class.new(gt: 0)
        errors, _ = validator.validate(1, ["age"])
        expect(errors).to be_empty
      end

      it "errors when value <= gt" do
        validator = validator_class.new(gt: 10)
        errors, _ = validator.validate(10, ["age"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:value_not_greater_than)
      end
    end

    context "with ge constraint" do
      it "validates when value >= ge" do
        validator = validator_class.new(ge: 0)
        errors, _ = validator.validate(0, ["age"])
        expect(errors).to be_empty
      end

      it "errors when value < ge" do
        validator = validator_class.new(ge: 10)
        errors, _ = validator.validate(5, ["age"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:value_not_greater_than_or_equal)
      end
    end

    context "with lt constraint" do
      it "validates when value < lt" do
        validator = validator_class.new(lt: 100)
        errors, _ = validator.validate(50, ["age"])
        expect(errors).to be_empty
      end

      it "errors when value >= lt" do
        validator = validator_class.new(lt: 100)
        errors, _ = validator.validate(100, ["age"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:value_not_less_than)
      end
    end

    context "with le constraint" do
      it "validates when value <= le" do
        validator = validator_class.new(le: 100)
        errors, _ = validator.validate(100, ["age"])
        expect(errors).to be_empty
      end

      it "errors when value > le" do
        validator = validator_class.new(le: 100)
        errors, _ = validator.validate(150, ["age"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:value_not_less_than_or_equal)
      end
    end

    context "with multiple_of constraint" do
      it "validates when value is multiple" do
        validator = validator_class.new(multiple_of: 5)
        errors, _ = validator.validate(15, ["age"])
        expect(errors).to be_empty
      end

      it "errors when value is not multiple" do
        validator = validator_class.new(multiple_of: 5)
        errors, _ = validator.validate(13, ["age"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:value_not_multiple_of)
      end
    end

    context "with combined constraints" do
      it "validates all constraints together" do
        validator = validator_class.new(ge: 1, le: 100, multiple_of: 2)
        errors, _ = validator.validate(50, ["age"])
        expect(errors).to be_empty
      end

      it "returns multiple errors" do
        validator = validator_class.new(ge: 1, le: 100, multiple_of: 2)
        errors, _ = validator.validate(0, ["age"])
        expect(errors.length).to eq(1) # only ge fails (0 IS a multiple of 2)
      end

      it "returns errors for non-multiple value" do
        validator = validator_class.new(ge: 1, le: 100, multiple_of: 2)
        errors, _ = validator.validate(7, ["age"]) # 7 is not multiple of 2
        expect(errors.length).to eq(1) # only multiple_of fails
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Float do
  let(:validator_class) { Rbdantic::Validators::Types::Float }

  describe "#validate" do
    context "with valid float" do
      it "returns no errors" do
        validator = validator_class.new
        errors, value = validator.validate(3.14, ["price"])
        expect(errors).to be_empty
        expect(value).to eq(3.14)
      end
    end

    context "with type coercion" do
      it "coerces Integer to Float" do
        validator = validator_class.new
        errors, value = validator.validate(42, ["price"])
        expect(errors).to be_empty
        expect(value).to eq(42.0)
      end

      it "coerces String to Float" do
        validator = validator_class.new
        errors, value = validator.validate("3.14", ["price"])
        expect(errors).to be_empty
        expect(value).to eq(3.14)
      end
    end

    context "with numeric constraints" do
      it "validates gt constraint" do
        validator = validator_class.new(gt: 0.0)
        errors, _ = validator.validate(0.5, ["price"])
        expect(errors).to be_empty
      end

      it "validates le constraint" do
        validator = validator_class.new(le: 100.0)
        errors, _ = validator.validate(99.99, ["price"])
        expect(errors).to be_empty
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Array do
  let(:validator_class) { Rbdantic::Validators::Types::Array }

  describe "#validate" do
    context "with valid array" do
      it "returns no errors" do
        validator = validator_class.new
        errors, value = validator.validate([1, 2, 3], ["items"])
        expect(errors).to be_empty
        expect(value).to eq([1, 2, 3])
      end
    end

    context "with type coercion" do
      it "coerces from to_a" do
        validator = validator_class.new
        errors, value = validator.validate((1..3), ["items"])
        expect(errors).to be_empty
        expect(value).to eq([1, 2, 3])
      end
    end

    context "with min_items constraint" do
      it "validates when length >= min_items" do
        validator = validator_class.new(min_items: 2)
        errors, _ = validator.validate([1, 2], ["items"])
        expect(errors).to be_empty
      end

      it "errors when length < min_items" do
        validator = validator_class.new(min_items: 3)
        errors, _ = validator.validate([1], ["items"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:array_too_short)
      end
    end

    context "with max_items constraint" do
      it "validates when length <= max_items" do
        validator = validator_class.new(max_items: 5)
        errors, _ = validator.validate([1, 2, 3], ["items"])
        expect(errors).to be_empty
      end

      it "errors when length > max_items" do
        validator = validator_class.new(max_items: 2)
        errors, _ = validator.validate([1, 2, 3], ["items"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:array_too_long)
      end
    end

    context "with unique_items constraint" do
      it "validates when items are unique" do
        validator = validator_class.new(unique_items: true)
        errors, _ = validator.validate([1, 2, 3], ["items"])
        expect(errors).to be_empty
      end

      it "errors when items are not unique" do
        validator = validator_class.new(unique_items: true)
        errors, _ = validator.validate([1, 1, 2], ["items"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:array_items_not_unique)
      end
    end

    context "with parameterized item type" do
      it "validates each item against item type" do
        validator = validator_class.new(min_items: 1, element_type: Integer)
        errors, value = validator.validate([1, 2, 3], ["items"])
        expect(errors).to be_empty
        expect(value).to eq([1, 2, 3])
      end

      it "errors on invalid item type" do
        validator = validator_class.new(min_items: 1, element_type: Integer)
        errors, _ = validator.validate([1, "invalid", 3], ["items"])
        expect(errors.length).to eq(1)
        expect(errors.first.loc).to eq(["items", 1])
        expect(errors.first.type).to eq(:type_error)
      end

      it "returns errors with correct location" do
        validator = validator_class.new(element_type: Integer)
        errors, _ = validator.validate([1, "bad", "also-bad"], ["items"])
        expect(errors.length).to eq(2)
        expect(errors[0].loc).to eq(["items", 1])
        expect(errors[1].loc).to eq(["items", 2])
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Model do
  before do
    class TestItem < Rbdantic::BaseModel
      field :name, String, min_length: 1
      field :value, Integer, ge: 0
    end
  end

  after do
    Object.send(:remove_const, :TestItem) if defined?(TestItem)
  end

  describe "#validate" do
    it "validates hash as nested model" do
      validator = Rbdantic::Validators::Types::Model.new(TestItem)
      errors, value = validator.validate({ name: "test", value: 5 }, ["items", 0])
      expect(errors).to be_empty
      expect(value).to be_a(TestItem)
      expect(value.name).to eq("test")
    end

    it "accepts existing model instance" do
      item = TestItem.new(name: "test", value: 5)
      validator = Rbdantic::Validators::Types::Model.new(TestItem)
      errors, value = validator.validate(item, ["items", 0])
      expect(errors).to be_empty
      expect(value).to eq(item)
    end

    it "maps nested errors to array location" do
      validator = Rbdantic::Validators::Types::Model.new(TestItem)
      errors, _ = validator.validate({ name: "", value: -1 }, ["items", 0])
      expect(errors.length).to eq(2)
      # Errors should be mapped to array index location
      expect(errors[0].loc.first).to eq("items")
      expect(errors[0].loc[1]).to eq(0)
    end
  end
end

RSpec.describe Rbdantic::Validators::Types do
  describe ".validator_class_for" do
    it "returns correct validator class" do
      expect(Rbdantic::Validators::Types.validator_class_for(String)).to eq(Rbdantic::Validators::Types::String)
      expect(Rbdantic::Validators::Types.validator_class_for(Integer)).to eq(Rbdantic::Validators::Types::Integer)
      expect(Rbdantic::Validators::Types.validator_class_for(Float)).to eq(Rbdantic::Validators::Types::Float)
      expect(Rbdantic::Validators::Types.validator_class_for(Rbdantic::Boolean)).to eq(Rbdantic::Validators::Types::Boolean)
      expect(Rbdantic::Validators::Types.validator_class_for(Array)).to eq(Rbdantic::Validators::Types::Array)
    end

    it "returns nil for unknown type" do
      expect(Rbdantic::Validators::Types.validator_class_for(Object)).to be_nil
    end
  end

  describe ".create_validator" do
    it "creates validator with constraints" do
      validator = Rbdantic::Validators::Types.create_validator(String, min_length: 5)
      expect(validator).to be_a(Rbdantic::Validators::Types::String)
      expect(validator.constraints[:min_length]).to eq(5)
    end

    it "creates Array validator with element_type" do
      validator = Rbdantic::Validators::Types.create_validator(Array, element_type: Integer, min_items: 1)
      expect(validator).to be_a(Rbdantic::Validators::Types::Array)
      expect(validator.element_type).to eq(Integer)
    end
  end

  describe ".has_validator?" do
    it "returns true for supported types" do
      expect(Rbdantic::Validators::Types.has_validator?(String)).to be true
      expect(Rbdantic::Validators::Types.has_validator?(Integer)).to be true
    end

    it "returns false for unsupported types" do
      expect(Rbdantic::Validators::Types.has_validator?(Object)).to be false
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Boolean do
  let(:validator_class) { Rbdantic::Validators::Types::Boolean }

  describe "#validate" do
    context "with valid boolean" do
      it "returns no errors for true" do
        validator = validator_class.new
        errors, value = validator.validate(true, ["flag"])
        expect(errors).to be_empty
        expect(value).to be true
      end

      it "returns no errors for false" do
        validator = validator_class.new
        errors, value = validator.validate(false, ["flag"])
        expect(errors).to be_empty
        expect(value).to be false
      end
    end

    context "with type coercion" do
      it "coerces string 'true' to true" do
        validator = validator_class.new
        errors, value = validator.validate("true", ["flag"])
        expect(errors).to be_empty
        expect(value).to be true
      end

      it "coerces string 'false' to false" do
        validator = validator_class.new
        errors, value = validator.validate("false", ["flag"])
        expect(errors).to be_empty
        expect(value).to be false
      end

      it "coerces 1 to true" do
        validator = validator_class.new
        errors, value = validator.validate(1, ["flag"])
        expect(errors).to be_empty
        expect(value).to be true
      end

      it "coerces 0 to false" do
        validator = validator_class.new
        errors, value = validator.validate(0, ["flag"])
        expect(errors).to be_empty
        expect(value).to be false
      end

      it "coerces 'yes' to true" do
        validator = validator_class.new
        errors, value = validator.validate("yes", ["flag"])
        expect(errors).to be_empty
        expect(value).to be true
      end

      it "coerces 'no' to false" do
        validator = validator_class.new
        errors, value = validator.validate("no", ["flag"])
        expect(errors).to be_empty
        expect(value).to be false
      end

      it "returns error for non-coercible types" do
        validator = validator_class.new
        errors, value = validator.validate("maybe", ["flag"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Hash do
  let(:validator_class) { Rbdantic::Validators::Types::Hash }

  describe "#validate" do
    context "with valid hash" do
      it "returns no errors" do
        validator = validator_class.new
        errors, value = validator.validate({ a: 1, b: 2 }, ["data"])
        expect(errors).to be_empty
        expect(value).to eq({ a: 1, b: 2 })
      end
    end

    context "with type coercion" do
      it "coerces array of pairs to hash" do
        validator = validator_class.new
        errors, value = validator.validate([[:a, 1], [:b, 2]], ["data"])
        expect(errors).to be_empty
        expect(value).to eq({ a: 1, b: 2 })
      end

      it "coerces JSON string to hash" do
        validator = validator_class.new
        errors, value = validator.validate('{"a":1,"b":2}', ["data"])
        expect(errors).to be_empty
        expect(value).to eq({ "a" => 1, "b" => 2 })
      end

      it "returns error for non-coercible types" do
        validator = validator_class.new
        errors, value = validator.validate([1, 2, 3], ["data"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Symbol do
  let(:validator_class) { Rbdantic::Validators::Types::Symbol }

  describe "#validate" do
    context "with valid symbol" do
      it "returns no errors" do
        validator = validator_class.new
        errors, value = validator.validate(:test, ["name"])
        expect(errors).to be_empty
        expect(value).to eq(:test)
      end
    end

    context "with type coercion" do
      it "coerces String to Symbol" do
        validator = validator_class.new
        errors, value = validator.validate("test", ["name"])
        expect(errors).to be_empty
        expect(value).to eq(:test)
      end

      it "returns error for empty string" do
        validator = validator_class.new
        errors, value = validator.validate("", ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end

      it "returns error for non-coercible types" do
        validator = validator_class.new
        errors, value = validator.validate([1, 2, 3], ["name"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Time do
  let(:validator_class) { Rbdantic::Validators::Types::Time }

  describe "#validate" do
    context "with valid Time" do
      it "returns no errors for Time object" do
        validator = validator_class.new
        time = Time.now
        errors, value = validator.validate(time, ["timestamp"])
        expect(errors).to be_empty
        expect(value).to eq(time)
      end
    end

    context "with type coercion" do
      it "coerces ISO8601 String to Time" do
        validator = validator_class.new
        errors, value = validator.validate("2024-01-15T10:30:00Z", ["timestamp"])
        expect(errors).to be_empty
        expect(value).to be_a(Time)
        expect(value.year).to eq(2024)
      end

      it "coerces Integer (Unix timestamp) to Time" do
        validator = validator_class.new
        errors, value = validator.validate(1_705_312_200, ["timestamp"])
        expect(errors).to be_empty
        expect(value).to be_a(Time)
      end

      it "coerces Float (Unix timestamp) to Time" do
        validator = validator_class.new
        errors, value = validator.validate(1_705_312_200.5, ["timestamp"])
        expect(errors).to be_empty
        expect(value).to be_a(Time)
        expect(value.nsec > 0).to be true
      end

      it "coerces DateTime to Time" do
        validator = validator_class.new
        dt = DateTime.new(2024, 1, 15, 10, 30, 0, "+8")
        errors, value = validator.validate(dt, ["timestamp"])
        expect(errors).to be_empty
        expect(value).to be_a(Time)
        expect(value.year).to eq(2024)
      end

      it "coerces Date to Time (at midnight)" do
        validator = validator_class.new
        date = Date.new(2024, 1, 15)
        errors, value = validator.validate(date, ["timestamp"])
        expect(errors).to be_empty
        expect(value).to be_a(Time)
        expect(value.hour).to eq(0)
        expect(value.min).to eq(0)
      end

      it "returns error for invalid string" do
        validator = validator_class.new
        errors, value = validator.validate("not-a-time", ["timestamp"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::Date do
  let(:validator_class) { Rbdantic::Validators::Types::Date }

  describe "#validate" do
    context "with valid Date" do
      it "returns no errors for Date object" do
        validator = validator_class.new
        date = Date.new(2024, 1, 15)
        errors, value = validator.validate(date, ["event_date"])
        expect(errors).to be_empty
        expect(value).to eq(date)
        expect(value.class).to eq(Date)  # not DateTime
      end

      it "rejects DateTime as Date type (needs coercion)" do
        validator = validator_class.new
        dt = DateTime.new(2024, 1, 15, 10, 30, 0)
        # DateTime should NOT match Date type directly
        expect(validator.matches_type?(dt)).to be false
      end
    end

    context "with type coercion" do
      it "coerces ISO8601 String to Date" do
        validator = validator_class.new
        errors, value = validator.validate("2024-01-15", ["event_date"])
        expect(errors).to be_empty
        expect(value).to be_a(Date)
        expect(value.year).to eq(2024)
        expect(value.month).to eq(1)
        expect(value.day).to eq(15)
      end

      it "coerces Time to Date" do
        validator = validator_class.new
        time = Time.new(2024, 1, 15, 10, 30, 0)
        errors, value = validator.validate(time, ["event_date"])
        expect(errors).to be_empty
        expect(value).to be_a(Date)
        expect(value.class).to eq(Date)  # ensure it's pure Date, not DateTime
        expect(value.year).to eq(2024)
        expect(value.day).to eq(15)
      end

      it "coerces DateTime to Date (drops time info)" do
        validator = validator_class.new
        dt = DateTime.new(2024, 1, 15, 10, 30, 0, "+8")
        errors, value = validator.validate(dt, ["event_date"])
        expect(errors).to be_empty
        expect(value).to be_a(Date)
        expect(value.class).to eq(Date)  # ensure it's pure Date, not DateTime
        expect(value.year).to eq(2024)
        expect(value.day).to eq(15)
        # Time info should be dropped
        expect(value).not_to respond_to(:hour)
      end

      it "coerces Integer (days since epoch) to Date" do
        validator = validator_class.new
        # 0 days = 1970-01-01
        errors, value = validator.validate(0, ["event_date"])
        expect(errors).to be_empty
        expect(value).to be_a(Date)
        expect(value).to eq(Date.new(1970, 1, 1))
      end

      it "coerces Float (days since epoch) to Date" do
        validator = validator_class.new
        # Float is truncated to integer days
        errors, value = validator.validate(1.5, ["event_date"])
        expect(errors).to be_empty
        expect(value).to be_a(Date)
        # 1.5 days gets truncated to 1 day = 1970-01-02
        expect(value.year).to eq(1970)
        expect(value.month).to eq(1)
        expect(value.day).to eq(2)
      end

      it "returns error for invalid string" do
        validator = validator_class.new
        errors, value = validator.validate("not-a-date", ["event_date"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end

      it "returns error for non-coercible types" do
        validator = validator_class.new
        errors, value = validator.validate([1, 2, 3], ["event_date"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end
  end
end

RSpec.describe Rbdantic::Validators::Types::DateTime do
  let(:validator_class) { Rbdantic::Validators::Types::DateTime }

  describe "#validate" do
    context "with valid DateTime" do
      it "returns no errors for DateTime object" do
        validator = validator_class.new
        dt = DateTime.new(2024, 1, 15, 10, 30, 0, "+8")
        errors, value = validator.validate(dt, ["created_at"])
        expect(errors).to be_empty
        expect(value).to eq(dt)
      end
    end

    context "with type coercion" do
      it "coerces ISO8601 String to DateTime" do
        validator = validator_class.new
        errors, value = validator.validate("2024-01-15T10:30:00+08:00", ["created_at"])
        expect(errors).to be_empty
        expect(value).to be_a(DateTime)
        expect(value.year).to eq(2024)
        expect(value.hour).to eq(10)
      end

      it "coerces Time to DateTime" do
        validator = validator_class.new
        time = Time.new(2024, 1, 15, 10, 30, 0, "+08:00")
        errors, value = validator.validate(time, ["created_at"])
        expect(errors).to be_empty
        expect(value).to be_a(DateTime)
        expect(value.year).to eq(2024)
        expect(value.hour).to eq(10)
      end

      it "coerces Date to DateTime (at midnight)" do
        validator = validator_class.new
        date = Date.new(2024, 1, 15)
        errors, value = validator.validate(date, ["created_at"])
        expect(errors).to be_empty
        expect(value).to be_a(DateTime)
        expect(value.year).to eq(2024)
        expect(value.hour).to eq(0)
        expect(value.min).to eq(0)
      end

      it "coerces Integer (Unix timestamp) to DateTime" do
        validator = validator_class.new
        # 86400 seconds = 1 day
        errors, value = validator.validate(86_400, ["created_at"])
        expect(errors).to be_empty
        expect(value).to be_a(DateTime)
        expect(value.day).to eq(2)  # 1970-01-02
      end

      it "coerces Float (Unix timestamp) to DateTime" do
        validator = validator_class.new
        errors, value = validator.validate(86_400.5, ["created_at"])
        expect(errors).to be_empty
        expect(value).to be_a(DateTime)
      end

      it "returns error for invalid string" do
        validator = validator_class.new
        errors, value = validator.validate("not-a-datetime", ["created_at"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end

      it "returns error for non-coercible types" do
        validator = validator_class.new
        errors, value = validator.validate([1, 2, 3], ["created_at"])
        expect(errors.length).to eq(1)
        expect(errors.first.type).to eq(:type_error)
      end
    end
  end
end
