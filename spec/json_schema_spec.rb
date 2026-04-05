# frozen_string_literal: true

require "spec_helper"

RSpec.describe "JSON Schema Generation" do
  describe ".model_json_schema" do
    it "generates basic JSON Schema for a model" do
      class SchemaModel1 < Rbdantic::BaseModel
        field :name, String
        field :age, Integer
        field :active, Rbdantic::Boolean
      end

      schema = SchemaModel1.model_json_schema

      expect(schema["$schema"]).to eq("https://json-schema.org/draft/2020-12/schema")
      expect(schema["type"]).to eq("object")
      expect(schema["properties"]).to have_key("name")
      expect(schema["properties"]).to have_key("age")
      expect(schema["properties"]).to have_key("active")
    end

    it "marks required fields in schema" do
      class SchemaModel2 < Rbdantic::BaseModel
        field :name, String
        field :nickname, String, optional: true
        field :email, String, default: "none"
      end

      schema = SchemaModel2.model_json_schema

      expect(schema["required"]).to eq(["name"])
      expect(schema["required"]).not_to include("nickname")
      expect(schema["required"]).not_to include("email")
    end

    it "includes title from class name" do
      class SchemaModelWithTitle < Rbdantic::BaseModel
        field :value, String
      end

      schema = SchemaModelWithTitle.model_json_schema
      expect(schema["title"]).to eq("SchemaModelWithTitle")
    end

    it "supports custom title and description" do
      class SchemaModel3 < Rbdantic::BaseModel
        field :id, Integer
      end

      schema = SchemaModel3.model_json_schema(
        title: "Custom Title",
        description: "A custom description"
      )

      expect(schema["title"]).to eq("Custom Title")
      expect(schema["description"]).to eq("A custom description")
    end

    it "supports custom schema_id" do
      class SchemaModel4 < Rbdantic::BaseModel
        field :data, Hash
      end

      schema = SchemaModel4.model_json_schema(schema_id: "https://example.com/schemas/model4")
      expect(schema["$id"]).to eq("https://example.com/schemas/model4")
    end
  end

  describe "type mappings" do
    it "maps String to string type" do
      class TypeMapString < Rbdantic::BaseModel
        field :value, String
      end

      schema = TypeMapString.model_json_schema
      expect(schema["properties"]["value"]["type"]).to eq("string")
    end

    it "maps Integer to integer type" do
      class TypeMapInt < Rbdantic::BaseModel
        field :value, Integer
      end

      schema = TypeMapInt.model_json_schema
      expect(schema["properties"]["value"]["type"]).to eq("integer")
    end

    it "maps Float to number type" do
      class TypeMapFloat < Rbdantic::BaseModel
        field :value, Float
      end

      schema = TypeMapFloat.model_json_schema
      expect(schema["properties"]["value"]["type"]).to eq("number")
    end

    it "maps Rbdantic::Boolean to boolean type" do
      class TypeMapBool < Rbdantic::BaseModel
        field :flag, Rbdantic::Boolean
      end

      schema = TypeMapBool.model_json_schema
      expect(schema["properties"]["flag"]["type"]).to eq("boolean")
    end

    it "maps Array to array type" do
      class TypeMapArray < Rbdantic::BaseModel
        field :items, Array
      end

      schema = TypeMapArray.model_json_schema
      expect(schema["properties"]["items"]["type"]).to eq("array")
    end

    it "maps Hash to object type" do
      class TypeMapHash < Rbdantic::BaseModel
        field :data, Hash
      end

      schema = TypeMapHash.model_json_schema
      expect(schema["properties"]["data"]["type"]).to eq("object")
    end
  end

  describe "constraint mappings" do
    describe "String constraints" do
      it "includes minLength in schema" do
        class StringConstraint1 < Rbdantic::BaseModel
          field :name, String, min_length: 3
        end

        schema = StringConstraint1.model_json_schema
        expect(schema["properties"]["name"]["minLength"]).to eq(3)
      end

      it "includes maxLength in schema" do
        class StringConstraint2 < Rbdantic::BaseModel
          field :code, String, max_length: 10
        end

        schema = StringConstraint2.model_json_schema
        expect(schema["properties"]["code"]["maxLength"]).to eq(10)
      end

      it "includes pattern in schema" do
        class StringConstraint3 < Rbdantic::BaseModel
          field :email, String, pattern: /\A[^@]+@[^@]+\z/
        end

        schema = StringConstraint3.model_json_schema
        expect(schema["properties"]["email"]["pattern"]).to eq("\\A[^@]+@[^@]+\\z")
      end

      it "includes format for email" do
        class StringConstraint4 < Rbdantic::BaseModel
          field :email, String, format: :email
        end

        schema = StringConstraint4.model_json_schema
        expect(schema["properties"]["email"]["format"]).to eq("email")
      end

      it "includes format for uri" do
        class StringConstraint5 < Rbdantic::BaseModel
          field :url, String, format: :uri
        end

        schema = StringConstraint5.model_json_schema
        expect(schema["properties"]["url"]["format"]).to eq("uri")
      end

      it "includes format for uuid" do
        class StringConstraint6 < Rbdantic::BaseModel
          field :id, String, format: :uuid
        end

        schema = StringConstraint6.model_json_schema
        expect(schema["properties"]["id"]["format"]).to eq("uuid")
      end
    end

    describe "Numeric constraints" do
      it "includes minimum (ge) in schema" do
        class NumericConstraint1 < Rbdantic::BaseModel
          field :value, Integer, ge: 0
        end

        schema = NumericConstraint1.model_json_schema
        expect(schema["properties"]["value"]["minimum"]).to eq(0)
      end

      it "includes exclusiveMinimum (gt) in schema" do
        class NumericConstraint2 < Rbdantic::BaseModel
          field :value, Integer, gt: 0
        end

        schema = NumericConstraint2.model_json_schema
        expect(schema["properties"]["value"]["exclusiveMinimum"]).to eq(0)
      end

      it "includes maximum (le) in schema" do
        class NumericConstraint3 < Rbdantic::BaseModel
          field :value, Integer, le: 100
        end

        schema = NumericConstraint3.model_json_schema
        expect(schema["properties"]["value"]["maximum"]).to eq(100)
      end

      it "includes exclusiveMaximum (lt) in schema" do
        class NumericConstraint4 < Rbdantic::BaseModel
          field :value, Integer, lt: 100
        end

        schema = NumericConstraint4.model_json_schema
        expect(schema["properties"]["value"]["exclusiveMaximum"]).to eq(100)
      end

      it "includes multipleOf in schema" do
        class NumericConstraint5 < Rbdantic::BaseModel
          field :value, Integer, multiple_of: 5
        end

        schema = NumericConstraint5.model_json_schema
        expect(schema["properties"]["value"]["multipleOf"]).to eq(5)
      end
    end

    describe "Array constraints" do
      it "includes minItems in schema" do
        class ArrayConstraint1 < Rbdantic::BaseModel
          field :items, Array, min_items: 1
        end

        schema = ArrayConstraint1.model_json_schema
        expect(schema["properties"]["items"]["minItems"]).to eq(1)
      end

      it "includes maxItems in schema" do
        class ArrayConstraint2 < Rbdantic::BaseModel
          field :items, Array, max_items: 10
        end

        schema = ArrayConstraint2.model_json_schema
        expect(schema["properties"]["items"]["maxItems"]).to eq(10)
      end

      it "includes uniqueItems in schema" do
        class ArrayConstraint3 < Rbdantic::BaseModel
          field :items, Array, unique_items: true
        end

        schema = ArrayConstraint3.model_json_schema
        expect(schema["properties"]["items"]["uniqueItems"]).to be true
      end

      it "includes item type schema" do
        class ArrayConstraint4 < Rbdantic::BaseModel
          field :items, [Integer]
        end

        schema = ArrayConstraint4.model_json_schema
        expect(schema["properties"]["items"]["items"]).to eq({ "type" => "integer" })
      end
    end
  end

  describe "default values in schema" do
    it "includes default values for static defaults" do
      class DefaultSchema1 < Rbdantic::BaseModel
        field :name, String, default: "unknown"
        field :count, Integer, default: 0
      end

      schema = DefaultSchema1.model_json_schema
      expect(schema["properties"]["name"]["default"]).to eq("unknown")
      expect(schema["properties"]["count"]["default"]).to eq(0)
    end

    it "excludes default values for default_factory" do
      class DefaultSchema2 < Rbdantic::BaseModel
        field :items, Array, default_factory: -> { [] }
      end

      schema = DefaultSchema2.model_json_schema
      expect(schema["properties"]["items"]).not_to have_key("default")
    end

    it "can exclude all defaults with include_defaults: false" do
      class DefaultSchema3 < Rbdantic::BaseModel
        field :name, String, default: "default"
      end

      schema = DefaultSchema3.model_json_schema(include_defaults: false)
      expect(schema["properties"]["name"]).not_to have_key("default")
    end
  end

  describe "nested models" do
    it "generates schema for nested model fields via refs" do
      class NestedInner < Rbdantic::BaseModel
        field :id, Integer
        field :name, String
      end

      class NestedOuter < Rbdantic::BaseModel
        field :inner, NestedInner
        field :count, Integer
      end

      schema = NestedOuter.model_json_schema

      # Outer model properties
      expect(schema["properties"]).to have_key("inner")
      expect(schema["properties"]).to have_key("count")

      # Nested model schema is centralized in $defs
      inner_schema = schema["properties"]["inner"]
      expect(inner_schema).to eq({ "$ref" => "#/$defs/NestedInner" })
      expect(schema["$defs"]).to include(
        "NestedInner" => include(
          "type" => "object",
          "properties" => include(
            "id" => { "type" => "integer" },
            "name" => { "type" => "string" }
          )
        )
      )

      # Top-level schema should not redundantly define itself in $defs
      expect(schema["$defs"]).not_to have_key("NestedOuter")
    end

    it "marks nested model fields as required when applicable" do
      class NestedRequiredInner < Rbdantic::BaseModel
        field :value, String
      end

      class NestedRequiredOuter < Rbdantic::BaseModel
        field :inner, NestedRequiredInner
        field :optional_inner, NestedRequiredInner, optional: true
      end

      schema = NestedRequiredOuter.model_json_schema
      expect(schema["required"]).to include("inner")
      expect(schema["required"]).not_to include("optional_inner")
    end
  end

  describe "optional fields" do
    it "allows null type for optional fields" do
      class OptionalSchema1 < Rbdantic::BaseModel
        field :required, String
        field :optional, String, optional: true
      end

      schema = OptionalSchema1.model_json_schema

      expect(schema["properties"]["required"]["type"]).to eq("string")
      expect(schema["properties"]["optional"]["type"]).to eq(["string", "null"])
    end
  end

  describe Rbdantic::JsonSchema::Types do
    describe ".to_schema" do
      it "returns base schema without constraints" do
        schema = Rbdantic::JsonSchema::Types.to_schema(String)
        expect(schema).to eq({ "type" => "string" })
      end

      it "applies constraints to base schema" do
        schema = Rbdantic::JsonSchema::Types.to_schema(String, min_length: 5)
        expect(schema["type"]).to eq("string")
        expect(schema["minLength"]).to eq(5)
      end
    end

    describe ".base_schema" do
      it "returns object schema for unknown types" do
        custom_type = Class.new
        schema = Rbdantic::JsonSchema::Types.base_schema(custom_type)
        expect(schema["type"]).to eq("object")
      end
    end
  end
end
