# frozen_string_literal: true

RSpec.describe "Nested model validation" do
  describe "single nested model" do
    before do
      # Define nested model
      class AddressModel < Rbdantic::BaseModel
        field :street, String, min_length: 1
        field :city, String, min_length: 1
        field :zip, String, pattern: /\A\d{5}\z/
      end

      # Define parent model with nested field
      class UserModel < Rbdantic::BaseModel
        field :name, String, min_length: 1
        field :address, AddressModel
      end
    end

    after do
      Object.send(:remove_const, :AddressModel) if defined?(AddressModel)
      Object.send(:remove_const, :UserModel) if defined?(UserModel)
    end

    it "validates nested model from hash input" do
      user = UserModel.new(
        name: "John",
        address: { street: "123 Main St", city: "Boston", zip: "02134" }
      )

      expect(user.name).to eq("John")
      expect(user.address).to be_a(AddressModel)
      expect(user.address.street).to eq("123 Main St")
      expect(user.address.city).to eq("Boston")
      expect(user.address.zip).to eq("02134")
    end

    it "accepts pre-constructed nested model instance" do
      address = AddressModel.new(street: "456 Oak Ave", city: "Cambridge", zip: "02139")
      user = UserModel.new(name: "Jane", address: address)

      expect(user.address).to eq(address)
    end

    it "raises ValidationError when nested model has invalid data" do
      expect {
        UserModel.new(
          name: "John",
          address: { street: "", city: "Boston", zip: "invalid" }
        )
      }.to raise_error(Rbdantic::ValidationError) do |error|
        errors = error.errors
        # Check that error paths reflect nested structure
        street_error = errors.find { |e| e.loc.include?(:street) }
        expect(street_error).not_to be_nil
        expect(street_error.loc).to eq([:address, :street])

        zip_error = errors.find { |e| e.loc.include?(:zip) }
        expect(zip_error).not_to be_nil
        expect(zip_error.loc).to eq([:address, :zip])
      end
    end

    it "raises ValidationError when nested field has wrong type" do
      expect {
        UserModel.new(name: "John", address: "not an address")
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.type).to eq(:type_error)
        expect(error.errors.first.loc).to eq([:address])
        expect(error.errors.first.msg).to include("Expected AddressModel")
      end
    end

    it "serializes nested model correctly in model_dump" do
      user = UserModel.new(
        name: "John",
        address: { street: "123 Main St", city: "Boston", zip: "02134" }
      )

      dump = user.model_dump
      expect(dump[:name]).to eq("John")
      expect(dump[:address]).to eq({ street: "123 Main St", city: "Boston", zip: "02134" })
    end

    it "rejects nested model instances that violate nested model validators" do
      class StrictChildModel < Rbdantic::BaseModel
        field :count, Integer
        model_config validate_assignment: false

        model_validator mode: :after do |model|
          raise "count must stay positive" if model.count <= 0
        end
      end

      class ParentWithStrictChild < Rbdantic::BaseModel
        field :child, StrictChildModel
      end

      child = StrictChildModel.new(count: 1)
      child.count = 0

      expect {
        ParentWithStrictChild.new(child: child)
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.type).to eq(:model_validation_failed)
        expect(error.errors.first.loc).to eq([:child])
      end
    end
  end

  describe "array of nested models" do
    before do
      Object.send(:remove_const, :ItemModel) if defined?(ItemModel)
      Object.send(:remove_const, :OrderModel) if defined?(OrderModel)

      # Define item model
      class ItemModel < Rbdantic::BaseModel
        field :name, String, min_length: 1
        field :quantity, Integer, gt: 0
      end

      # Define order model with array of items
      class OrderModel < Rbdantic::BaseModel
        field :order_id, String
        field :items, [ItemModel], min_items: 1
      end
    end

    after do
      Object.send(:remove_const, :ItemModel) if defined?(ItemModel)
      Object.send(:remove_const, :OrderModel) if defined?(OrderModel)
    end

    it "validates array of nested models from array of hashes" do
      order = OrderModel.new(
        order_id: "ORD-001",
        items: [
          { name: "Widget", quantity: 5 },
          { name: "Gadget", quantity: 2 }
        ]
      )

      expect(order.items).to be_a(Array)
      expect(order.items.length).to eq(2)
      expect(order.items[0]).to be_a(ItemModel)
      expect(order.items[0].name).to eq("Widget")
      expect(order.items[1].name).to eq("Gadget")
    end

    it "accepts pre-constructed nested model instances in array" do
      item1 = ItemModel.new(name: "Widget", quantity: 5)
      item2 = ItemModel.new(name: "Gadget", quantity: 2)
      order = OrderModel.new(order_id: "ORD-002", items: [item1, item2])

      expect(order.items[0]).to eq(item1)
      expect(order.items[1]).to eq(item2)
    end

    it "raises ValidationError when array item has invalid data" do
      expect {
        OrderModel.new(
          order_id: "ORD-003",
          items: [
            { name: "Widget", quantity: 5 },
            { name: "", quantity: 0 }  # Invalid item
          ]
        )
      }.to raise_error(Rbdantic::ValidationError) do |error|
        errors = error.errors

        # Find error for item at index 1
        item_error = errors.find { |e| e.loc.include?(1) }
        expect(item_error).not_to be_nil
        expect(item_error.loc[0]).to eq(:items)
        expect(item_error.loc[1]).to eq(1)
      end
    end

    it "validates min_items constraint on array" do
      expect {
        OrderModel.new(order_id: "ORD-004", items: [])
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.type).to eq(:array_too_short)
        expect(error.errors.first.loc).to eq([:items])
      end
    end

    it "serializes array of nested models correctly in model_dump" do
      order = OrderModel.new(
        order_id: "ORD-001",
        items: [
          { name: "Widget", quantity: 5 },
          { name: "Gadget", quantity: 2 }
        ]
      )

      dump = order.model_dump
      expect(dump[:order_id]).to eq("ORD-001")
      expect(dump[:items]).to eq([
        { name: "Widget", quantity: 5 },
        { name: "Gadget", quantity: 2 }
      ])
    end
  end

  describe "deeply nested models" do
    before do
      class CountryModel < Rbdantic::BaseModel
        field :code, String, pattern: /\A[A-Z]{2}\z/
        field :name, String
      end

      class CityModel < Rbdantic::BaseModel
        field :name, String
        field :country, CountryModel
      end

      class PersonModel < Rbdantic::BaseModel
        field :name, String
        field :birthplace, CityModel
      end
    end

    after do
      Object.send(:remove_const, :CountryModel) if defined?(CountryModel)
      Object.send(:remove_const, :CityModel) if defined?(CityModel)
      Object.send(:remove_const, :PersonModel) if defined?(PersonModel)
    end

    it "validates deeply nested models" do
      person = PersonModel.new(
        name: "Alice",
        birthplace: {
          name: "Paris",
          country: { code: "FR", name: "France" }
        }
      )

      expect(person.birthplace).to be_a(CityModel)
      expect(person.birthplace.country).to be_a(CountryModel)
      expect(person.birthplace.country.code).to eq("FR")
    end

    it "reports errors with correct nested path" do
      expect {
        PersonModel.new(
          name: "Bob",
          birthplace: {
            name: "London",
            country: { code: "invalid", name: "UK" }  # Invalid code
          }
        )
      }.to raise_error(Rbdantic::ValidationError) do |error|
        code_error = error.errors.find { |e| e.loc.include?(:code) }
        expect(code_error).not_to be_nil
        expect(code_error.loc).to eq([:birthplace, :country, :code])
      end
    end
  end

  describe "array item type validation" do
    it "validates built-in item types" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :numbers, [Integer]
      end

      expect {
        klass.new(numbers: [1, "two", 3])
      }.to raise_error(Rbdantic::ValidationError) do |error|
        expect(error.errors.first.loc).to eq([:numbers, 1])
        expect(error.errors.first.type).to eq(:type_error)
      end
    end

    it "coerces built-in item types when possible" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :numbers, [Integer]
      end

      model = klass.new(numbers: ["1", "2", 3])
      expect(model.numbers).to eq([1, 2, 3])
    end

    it "supports boolean aliases as array element types" do
      klass = Class.new(Rbdantic::BaseModel) do
        field :flags, [Rbdantic::Boolean]
      end

      model = klass.new(flags: ["true", false, 1, 0])
      expect(model.flags).to eq([true, false, true, false])
    end
  end
end
