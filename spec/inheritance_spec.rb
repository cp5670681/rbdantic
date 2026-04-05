# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Inheritance" do
  describe "field inheritance" do
    it "inherits fields from parent class" do
      class ParentModel1 < Rbdantic::BaseModel
        field :name, String
        field :age, Integer
      end

      class ChildModel1 < ParentModel1
        field :email, String
      end

      expect(ChildModel1.fields.keys).to contain_exactly(:name, :age, :email)
      expect(ChildModel1.fields[:name].type).to eq(String)
      expect(ChildModel1.fields[:age].type).to eq(Integer)
      expect(ChildModel1.fields[:email].type).to eq(String)
    end

    it "does not modify parent fields when child adds fields" do
      class ParentModel2 < Rbdantic::BaseModel
        field :name, String
      end

      class ChildModel2 < ParentModel2
        field :extra, String
      end

      expect(ParentModel2.fields.keys).to eq([:name])
      expect(ChildModel2.fields.keys).to contain_exactly(:name, :extra)
    end

    it "inherits fields through multiple levels" do
      class GrandParent < Rbdantic::BaseModel
        field :id, Integer
      end

      class ParentModel3 < GrandParent
        field :name, String
      end

      class ChildModel3 < ParentModel3
        field :email, String
      end

      expect(ChildModel3.fields.keys).to contain_exactly(:id, :name, :email)
      expect(ChildModel3.fields[:id].type).to eq(Integer)
      expect(ChildModel3.fields[:name].type).to eq(String)
      expect(ChildModel3.fields[:email].type).to eq(String)
    end
  end

  describe "config inheritance" do
    it "inherits model_config from parent" do
      class ParentConfig1 < Rbdantic::BaseModel
        field :name, String
        model_config extra: :forbid
      end

      class ChildConfig1 < ParentConfig1
        field :email, String
      end

      # Child should inherit parent's config
      expect(ChildConfig1.model_config.extra).to eq(:forbid)

      # Child should have parent + own fields
      expect(ChildConfig1.fields.keys).to contain_exactly(:name, :email)
    end

    it "allows child to override config" do
      class ParentConfig2 < Rbdantic::BaseModel
        field :name, String
        model_config extra: :forbid, frozen: false
      end

      class ChildConfig2 < ParentConfig2
        field :email, String
        model_config extra: :allow, frozen: true
      end

      expect(ParentConfig2.model_config.extra).to eq(:forbid)
      expect(ParentConfig2.model_config.frozen).to be false

      expect(ChildConfig2.model_config.extra).to eq(:allow)
      expect(ChildConfig2.model_config.frozen).to be true
    end

    it "inherits config through multiple levels" do
      class ConfigGrandParent < Rbdantic::BaseModel
        field :id, Integer
        model_config strict: true
      end

      class ConfigParent < ConfigGrandParent
        field :name, String
        model_config extra: :forbid
      end

      class ConfigChild < ConfigParent
        field :email, String
      end

      expect(ConfigChild.model_config.strict).to be true
      expect(ConfigChild.model_config.extra).to eq(:forbid)
    end
  end

  describe "constraint inheritance" do
    it "inherits field constraints from parent" do
      class ParentConstraints < Rbdantic::BaseModel
        field :name, String, min_length: 3, max_length: 50
      end

      class ChildConstraints < ParentConstraints
        field :email, String
      end

      parent_field = ParentConstraints.fields[:name]
      child_field = ChildConstraints.fields[:name]

      expect(child_field.constraints[:min_length]).to eq(3)
      expect(child_field.constraints[:max_length]).to eq(50)
      expect(parent_field.constraints).to eq(child_field.constraints)
    end

    it "inherits default values from parent" do
      class ParentDefaults < Rbdantic::BaseModel
        field :status, String, default: "active"
        field :count, Integer, default: 0
      end

      class ChildDefaults < ParentDefaults
        field :name, String
      end

      expect(ChildDefaults.fields[:status].default).to eq("active")
      expect(ChildDefaults.fields[:count].default).to eq(0)
    end

    it "inherits default_factory from parent" do
      class ParentFactory < Rbdantic::BaseModel
        field :items, Array, default_factory: -> { [] }
      end

      class ChildFactory < ParentFactory
        field :name, String
      end

      expect(ChildFactory.fields[:items].default_factory).not_to be_nil
      model = ChildFactory.new(name: "test")
      expect(model.items).to eq([])
    end

    it "inherits validators from parent" do
      class ParentValidators < Rbdantic::BaseModel
        field :email, String, validators: [->(v) { v.include?("@") || false }]
      end

      class ChildValidators < ParentValidators
        field :name, String
      end

      expect(ChildValidators.fields[:email].validators.length).to eq(1)

      # Child model should validate inherited validators
      expect {
        ChildValidators.new(email: "invalid", name: "test")
      }.to raise_error(Rbdantic::ValidationError)

      model = ChildValidators.new(email: "valid@example.com", name: "test")
      expect(model.email).to eq("valid@example.com")
    end

    it "inherits optional flag from parent" do
      class ParentOptional < Rbdantic::BaseModel
        field :required, String
        field :optional, String, optional: true
      end

      class ChildOptional < ParentOptional
        field :extra, String
      end

      expect(ChildOptional.fields[:required].required?).to be true
      expect(ChildOptional.fields[:optional].required?).to be false
      expect(ChildOptional.fields[:optional].optional).to be true
    end
  end

  describe "initialization with inherited fields" do
    it "validates inherited fields correctly" do
      class ParentInit < Rbdantic::BaseModel
        field :name, String, min_length: 3
      end

      class ChildInit < ParentInit
        field :email, String
      end

      model = ChildInit.new(name: "John", email: "john@example.com")
      expect(model.name).to eq("John")
      expect(model.email).to eq("john@example.com")

      # Inherited constraint should apply
      expect {
        ChildInit.new(name: "Jo", email: "test@example.com")
      }.to raise_error(Rbdantic::ValidationError) do |e|
        expect(e.errors.first.type).to eq(:string_too_short)
        expect(e.errors.first.loc).to eq([:name])
      end
    end

    it "uses inherited defaults correctly" do
      class ParentInitDefaults < Rbdantic::BaseModel
        field :status, String, default: "active"
      end

      class ChildInitDefaults < ParentInitDefaults
        field :name, String
      end

      model = ChildInitDefaults.new(name: "test")
      expect(model.name).to eq("test")
      expect(model.status).to eq("active")
    end
  end

  describe "model_dump with inherited fields" do
    it "includes inherited fields in dump" do
      class ParentDump < Rbdantic::BaseModel
        field :id, Integer
        field :name, String
      end

      class ChildDump < ParentDump
        field :email, String
      end

      model = ChildDump.new(id: 1, name: "test", email: "test@example.com")
      result = model.model_dump

      expect(result).to eq({
        id: 1,
        name: "test",
        email: "test@example.com"
      })
    end

    it "serializes inherited defaults correctly" do
      class ParentDumpDefaults < Rbdantic::BaseModel
        field :status, String, default: "active"
      end

      class ChildDumpDefaults < ParentDumpDefaults
        field :name, String
      end

      model = ChildDumpDefaults.new(name: "test")
      result = model.model_dump

      expect(result).to eq({ status: "active", name: "test" })

      # With exclude_defaults
      result_no_defaults = model.model_dump(exclude_defaults: true)
      expect(result_no_defaults).to eq({ name: "test" })
    end
  end

  describe "model_json_schema with inherited fields" do
    it "generates schema including inherited fields" do
      class ParentSchema < Rbdantic::BaseModel
        field :id, Integer
        field :name, String
      end

      class ChildSchema < ParentSchema
        field :email, String
      end

      schema = ChildSchema.model_json_schema

      expect(schema["properties"]).to have_key("id")
      expect(schema["properties"]).to have_key("name")
      expect(schema["properties"]).to have_key("email")

      expect(schema["required"]).to contain_exactly("id", "name", "email")
    end

    it "includes inherited constraints in schema" do
      class ParentSchemaConstraints < Rbdantic::BaseModel
        field :name, String, min_length: 3, max_length: 50
      end

      class ChildSchemaConstraints < ParentSchemaConstraints
        field :email, String
      end

      schema = ChildSchemaConstraints.model_json_schema

      expect(schema["properties"]["name"]["minLength"]).to eq(3)
      expect(schema["properties"]["name"]["maxLength"]).to eq(50)
    end

    it "includes inherited defaults in schema" do
      class ParentSchemaDefaults < Rbdantic::BaseModel
        field :status, String, default: "active"
      end

      class ChildSchemaDefaults < ParentSchemaDefaults
        field :name, String
      end

      schema = ChildSchemaDefaults.model_json_schema

      expect(schema["properties"]["status"]["default"]).to eq("active")
      expect(schema["required"]).to eq(["name"])
    end
  end
end
