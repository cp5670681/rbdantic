# frozen_string_literal: true

require "json"
require "spec_helper"

module PydanticCompatSpec
  class Address < Rbdantic::BaseModel
    field :city, String, min_length: 2
    field :zip, Integer
  end

  class User < Rbdantic::BaseModel
    model_config extra: :allow, validate_assignment: false

    field :id, Integer
    field :name, String, Rbdantic::Field.new(default: "Jane")
    field :active, Rbdantic::Boolean, default: true
    field :tags, [String], default_factory: -> { [] }
    field :nickname, String, required: false
    field :address, Address
  end

  class ParentConfig < Rbdantic::BaseModel
    model_config extra: :allow, strict: true

    field :id, Integer
  end

  class ChildConfig < ParentConfig
    model_config validate_assignment: false

    field :name, String
  end
end

RSpec.describe "Pydantic-style compatibility" do
  it "exposes BaseModel as the public model base" do
    expect(Rbdantic::BaseModel).to be_a(Class)
    expect(Rbdantic.constants).not_to include(:Base)
  end

  it "supports model_validate, model_fields, model_fields_set, and model_extra" do
    user = PydanticCompatSpec::User.model_validate(
      "id" => 7,
      "active" => "false",
      "tags" => [:ruby, "dsl"],
      "address" => { "city" => "Shanghai", "zip" => "200000" },
      "role" => "core"
    )

    expect(PydanticCompatSpec::User.model_fields.keys).to include(:id, :name, :active, :tags, :nickname, :address)
    expect(user.id).to eq(7)
    expect(user.active).to eq(false)
    expect(user.tags).to eq(%w[ruby dsl])
    expect(user.address.city).to eq("Shanghai")
    expect(user.address.zip).to eq(200_000)
    expect(user.model_fields_set).to eq(Set[:id, :active, :tags, :address, :role])
    expect(user.model_extra).to eq(role: "core")
    expect(user.role).to eq("core")
  end

  it "supports Field metadata objects and required: false" do
    user = PydanticCompatSpec::User.new(id: 1, address: { city: "LA", zip: 90_001 })

    expect(user.name).to eq("Jane")
    expect(user.nickname).to be_nil
  end

  it "supports typed-array shorthand and Boolean alias in field declarations" do
    user = PydanticCompatSpec::User.new(
      id: 3,
      active: "true",
      tags: [:ruby, "api"],
      address: { city: "Tokyo", zip: 100_000 }
    )

    expect(user.active).to eq(true)
    expect(user.tags).to eq(%w[ruby api])
    expect(PydanticCompatSpec::User.model_fields[:active].type).to eq(Rbdantic::Boolean)
    expect(PydanticCompatSpec::User.model_fields[:tags].constraints[:element_type]).to eq(String)
  end

  it "merges model_config with inherited values instead of replacing the parent config" do
    expect(PydanticCompatSpec::ChildConfig.model_config.extra).to eq(:allow)
    expect(PydanticCompatSpec::ChildConfig.model_config.strict).to be(true)
    expect(PydanticCompatSpec::ChildConfig.model_config.validate_assignment).to be(false)
  end

  it "exposes model_json_schema as a pydantic-style alias" do
    schema = PydanticCompatSpec::User.model_json_schema

    expect(schema["properties"]).to have_key("tags")
    expect(schema["properties"]["tags"]["type"]).to eq("array")
    expect(schema["properties"]["tags"]["items"]).to eq({ "type" => "string" })
  end

  it "allows model_dump_json to accept dump filters" do
    user = PydanticCompatSpec::User.new(id: 5, address: { city: "Paris", zip: 75_000 }, role: "staff")

    expect(JSON.parse(user.model_dump_json(include: %i[id role]))).to eq(
      "id" => 5,
      "role" => "staff"
    )
  end
end
