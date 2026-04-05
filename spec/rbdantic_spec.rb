# frozen_string_literal: true

RSpec.describe Rbdantic do
  it "has a version number" do
    expect(Rbdantic::VERSION).not_to be nil
  end

  it "provides BaseModel class for data models" do
    model_class = Class.new(Rbdantic::BaseModel) do
      field :name, String, min_length: 1
      field :count, Integer, default: 0
    end

    model = model_class.new(name: "test")
    expect(model.name).to eq("test")
    expect(model.count).to eq(0)
    expect(model.model_dump).to eq({ name: "test", count: 0 })
  end

  it "raises ValidationError for invalid data" do
    model_class = Class.new(Rbdantic::BaseModel) do
      field :name, String, min_length: 5
      model_config extra: :forbid
    end

    expect {
      model_class.new(name: "abc")
    }.to raise_error(Rbdantic::ValidationError)
  end
end
