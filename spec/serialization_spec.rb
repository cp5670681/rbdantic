# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Serialization" do
  describe "#model_dump" do
    it "returns hash of all field values" do
      class SerializeModel1 < Rbdantic::BaseModel
        field :name, String
        field :count, Integer, default: 0
      end

      model = SerializeModel1.new(name: "test", count: 5)
      result = model.model_dump

      expect(result).to eq({ name: "test", count: 5 })
    end

    it "includes fields with default values" do
      class SerializeModel2 < Rbdantic::BaseModel
        field :name, String, default: "unknown"
        field :active, Rbdantic::Boolean, default: true
      end

      model = SerializeModel2.new
      result = model.model_dump

      expect(result).to eq({ name: "unknown", active: true })
    end

    it "handles nested models" do
      class InnerModel < Rbdantic::BaseModel
        field :value, String
      end

      class OuterModel < Rbdantic::BaseModel
        field :inner, InnerModel
        field :name, String
      end

      model = OuterModel.new(
        inner: InnerModel.new(value: "nested"),
        name: "outer"
      )

      result = model.model_dump
      expect(result).to eq({
        inner: { value: "nested" },
        name: "outer"
      })
    end

    it "handles arrays of nested models" do
      class ItemModel < Rbdantic::BaseModel
        field :id, Integer
      end

      class ContainerModel < Rbdantic::BaseModel
        field :items, Array
      end

      model = ContainerModel.new(
        items: [
          ItemModel.new(id: 1),
          ItemModel.new(id: 2),
          ItemModel.new(id: 3)
        ]
      )

      result = model.model_dump
      expect(result).to eq({
        items: [
          { id: 1 },
          { id: 2 },
          { id: 3 }
        ]
      })
    end

    it "handles hash with nested models" do
      class EntryModel < Rbdantic::BaseModel
        field :key, String
      end

      class MapModel < Rbdantic::BaseModel
        field :entries, Hash
      end

      model = MapModel.new(
        entries: {
          a: EntryModel.new(key: "alpha"),
          b: EntryModel.new(key: "beta")
        }
      )

      result = model.model_dump
      expect(result[:entries][:a]).to eq({ key: "alpha" })
      expect(result[:entries][:b]).to eq({ key: "beta" })
    end

    it "recursively serializes nested models inside arrays and hashes" do
      class DeepInnerModel < Rbdantic::BaseModel
        field :value, String
      end

      class DeepOuterModel < Rbdantic::BaseModel
        field :payload, Hash
      end

      model = DeepOuterModel.new(
        payload: {
          list: [
            { item: DeepInnerModel.new(value: "a") },
            DeepInnerModel.new(value: "b")
          ]
        }
      )

      expect(model.model_dump).to eq(
        payload: {
          list: [
            { item: { value: "a" } },
            { value: "b" }
          ]
        }
      )
    end
  end

  describe "#model_dump with exclude_defaults" do
    it "excludes fields with default values when exclude_defaults: true" do
      class SerializeModel3 < Rbdantic::BaseModel
        field :name, String
        field :status, String, default: "active"
        field :count, Integer, default: 0
      end

      model = SerializeModel3.new(name: "test")
      result = model.model_dump(exclude_defaults: true)

      expect(result).to eq({ name: "test" })
      expect(result).not_to have_key(:status)
      expect(result).not_to have_key(:count)
    end

    it "includes fields when value differs from default" do
      class SerializeModel4 < Rbdantic::BaseModel
        field :name, String
        field :status, String, default: "active"
      end

      model = SerializeModel4.new(name: "test", status: "inactive")
      result = model.model_dump(exclude_defaults: true)

      expect(result).to eq({ name: "test", status: "inactive" })
    end

    it "includes fields without defaults" do
      class SerializeModel5 < Rbdantic::BaseModel
        field :name, String
        field :optional, String, optional: true
      end

      model = SerializeModel5.new(name: "test", optional: "value")
      result = model.model_dump(exclude_defaults: true)

      expect(result).to eq({ name: "test", optional: "value" })
    end

    it "does not invoke default_factory during dumping" do
      factory_calls = 0

      klass = Class.new(Rbdantic::BaseModel) do
        field :items, Array, default_factory: -> { factory_calls += 1; [] }
      end

      model = klass.new
      expect(factory_calls).to eq(1)

      result = model.model_dump(exclude_defaults: true)

      expect(result).to eq({ items: [] })
      expect(factory_calls).to eq(1)
    end
  end

  describe "#model_dump with exclude_unset" do
    it "excludes fields that were not explicitly set" do
      class SerializeModel6 < Rbdantic::BaseModel
        field :name, String
        field :nickname, String, optional: true
      end

      model = SerializeModel6.new(name: "test")
      result = model.model_dump(exclude_unset: true)

      expect(result).to eq({ name: "test" })
    end

    it "excludes defaulted fields that were not provided" do
      class SerializeModel6a < Rbdantic::BaseModel
        field :name, String, default: "unknown"
        field :age, Integer, default: 0
      end

      expect(SerializeModel6a.new.model_dump(exclude_unset: true)).to eq({})
    end

    it "keeps explicitly provided nil fields" do
      class SerializeModel6b < Rbdantic::BaseModel
        field :name, String
        field :nickname, String, optional: true
      end

      model = SerializeModel6b.new(name: "test", nickname: nil)
      expect(model.model_dump(exclude_unset: true)).to eq({ name: "test", nickname: nil })
    end

    it "includes fields explicitly assigned after initialization" do
      class SerializeModel6c < Rbdantic::BaseModel
        field :name, String
        field :nickname, String, optional: true
      end

      model = SerializeModel6c.new(name: "test")
      model.nickname = "nick"

      expect(model.model_dump(exclude_unset: true)).to eq({ name: "test", nickname: "nick" })
    end
  end

  describe "#model_dump with include option" do
    it "includes only specified fields" do
      class SerializeModel7 < Rbdantic::BaseModel
        field :name, String
        field :email, String
        field :age, Integer
      end

      model = SerializeModel7.new(name: "test", email: "test@example.com", age: 25)
      result = model.model_dump(include: [:name, :email])

      expect(result).to eq({ name: "test", email: "test@example.com" })
      expect(result).not_to have_key(:age)
    end

    it "does not leak top-level include filters into nested models" do
      user_class = Class.new(Rbdantic::BaseModel) do
        field :name, String
        field :age, Integer
      end

      model_class = Class.new(Rbdantic::BaseModel) do
        field :user, user_class
        field :status, String
      end

      model = model_class.new(
        user: { name: "test", age: 20 },
        status: "active"
      )

      expect(model.model_dump(include: [:user])).to eq(
        user: { name: "test", age: 20 }
      )
    end
  end

  describe "#model_dump with exclude option" do
    it "excludes specified fields" do
      class SerializeModel8 < Rbdantic::BaseModel
        field :name, String
        field :email, String
        field :password, String
      end

      model = SerializeModel8.new(name: "test", email: "test@example.com", password: "secret")
      result = model.model_dump(exclude: [:password])

      expect(result).to eq({ name: "test", email: "test@example.com" })
      expect(result).not_to have_key(:password)
    end
  end

  describe "extra fields" do
    it "serializes allowed extra fields" do
      class SerializeExtraModel < Rbdantic::BaseModel
        field :name, String
        model_config extra: :allow
      end

      model = SerializeExtraModel.new(name: "test", role: "admin")
      expect(model.model_dump).to eq({ name: "test", role: "admin" })
    end
  end

  describe "#model_dump_json" do
    it "returns JSON string of model data" do
      class SerializeModel9 < Rbdantic::BaseModel
        field :name, String
        field :count, Integer
      end

      model = SerializeModel9.new(name: "test", count: 42)
      json = model.model_dump_json

      expect(json).to be_a(String)
      parsed = JSON.parse(json, symbolize_names: true)
      expect(parsed).to eq({ name: "test", count: 42 })
    end

    it "supports indent option for pretty output" do
      class SerializeModel10 < Rbdantic::BaseModel
        field :name, String
        field :items, Array
      end

      model = SerializeModel10.new(name: "test", items: [1, 2, 3])
      # Without indent, returns compact JSON
      json_compact = model.model_dump_json
      expect(json_compact).not_to include("\n")

      json_pretty = model.model_dump_json(indent: 2)
      expect(json_pretty).to include("\n")
      expect(JSON.parse(json_pretty, symbolize_names: true)).to eq(name: "test", items: [1, 2, 3])
    end

    it "handles nested models in JSON" do
      class JsonInner < Rbdantic::BaseModel
        field :value, String
      end

      class JsonOuter < Rbdantic::BaseModel
        field :inner, JsonInner
      end

      model = JsonOuter.new(inner: JsonInner.new(value: "nested"))
      json = model.model_dump_json

      parsed = JSON.parse(json, symbolize_names: true)
      expect(parsed).to eq({ inner: { value: "nested" } })
    end
  end

  describe Rbdantic::Serialization::JsonSerializer do
    describe ".load" do
      it "parses JSON string into model" do
        class JsonLoadModel < Rbdantic::BaseModel
          field :name, String
          field :count, Integer
        end

        json = '{"name":"test","count":42}'
        model = Rbdantic::Serialization::JsonSerializer.load(json, JsonLoadModel)

        expect(model).to be_a(JsonLoadModel)
        expect(model.name).to eq("test")
        expect(model.count).to eq(42)
      end

      it "raises ValidationError for invalid data" do
        class JsonLoadStrict < Rbdantic::BaseModel
          field :count, Integer, gt: 0
        end

        json = '{"count":-5}'
        expect {
          Rbdantic::Serialization::JsonSerializer.load(json, JsonLoadStrict)
        }.to raise_error(Rbdantic::ValidationError)
      end
    end

    describe ".parse" do
      it "returns model on valid JSON" do
        class JsonParseModel < Rbdantic::BaseModel
          field :name, String
        end

        json = '{"name":"test"}'
        model = Rbdantic::Serialization::JsonSerializer.parse(json, JsonParseModel)

        expect(model).to be_a(JsonParseModel)
        expect(model.name).to eq("test")
      end

      it "returns nil on invalid JSON" do
        class JsonParseModel2 < Rbdantic::BaseModel
          field :name, String
        end

        model = Rbdantic::Serialization::JsonSerializer.parse("invalid json", JsonParseModel2)
        expect(model).to be_nil
      end

      it "returns nil on validation error" do
        class JsonParseModel3 < Rbdantic::BaseModel
          field :count, Integer, gt: 0
        end

        json = '{"count":-5}'
        model = Rbdantic::Serialization::JsonSerializer.parse(json, JsonParseModel3)
        expect(model).to be_nil
      end
    end

    describe ".parse!" do
      it "raises on invalid JSON" do
        class JsonParseStrict < Rbdantic::BaseModel
          field :name, String
        end

        expect {
          Rbdantic::Serialization::JsonSerializer.parse!("invalid", JsonParseStrict)
        }.to raise_error(JSON::ParserError)
      end
    end
  end
end
