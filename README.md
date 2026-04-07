# Rbdantic

**Ruby Data Validation and Settings Management** - A Pydantic-inspired data validation library for Ruby.

Rbdantic brings Pydantic's powerful data validation capabilities to Ruby, providing runtime data validation, serialization, and JSON Schema generation with an intuitive DSL.

[中文文档](README_CN.md)

## Features

- **Base Model Class** - Define data models with type-checked fields
- **Field Constraints** - Built-in constraints for strings, numbers, and arrays
- **Custom Validators** - Field-level and model-level validators with multiple modes
- **Type Coercion** - Automatic type conversion with configurable strictness
- **Nested Models** - Support for nested model validation
- **Model Inheritance** - Fields and validators are inherited by subclasses
- **Model Configuration** - Flexible configuration options (extra fields, frozen models, etc.)
- **Serialization** - Convert models to Hash or JSON with filtering options
- **JSON Schema Generation** - Automatic JSON Schema generation for API documentation
- **Detailed Error Reporting** - Structured validation errors with location paths

## Installation

Add to your Gemfile:

```ruby
gem 'rbdantic'
```

Or install directly:

```bash
gem install rbdantic
```

## Quick Start

```ruby
require 'rbdantic'

class User < Rbdantic::BaseModel
  field :name, String, min_length: 1, max_length: 100
  field :email, String, pattern: /\A[^@\s]+@[^@\s]+\z/
  field :age, Integer, gt: 0, le: 150
  field :tags, [String], default_factory: -> { [] }
end

# Create a valid user
user = User.new(
  name: "Alice",
  email: "alice@example.com",
  age: 30
)

puts user.name   # => "Alice"
puts user.age    # => 30
puts user.tags   # => []

# Serialize to Hash
puts user.model_dump
# => { name: "Alice", email: "alice@example.com", age: 30, tags: [] }

# to_h is an alias for model_dump
puts user.to_h
# => { name: "Alice", email: "alice@example.com", age: 30, tags: [] }

# Serialize to JSON
puts user.model_dump_json
# => {"name":"Alice","email":"alice@example.com","age":30,"tags":[]}

# Validation error
begin
  User.new(name: "", email: "invalid", age: -1)
rescue Rbdantic::ValidationError => e
  e.errors.each do |err|
    puts "#{err.loc.join('.')}: #{err.msg}"
  end
  # name: String must be at least 1 characters
  # email: String does not match pattern ...
  # age: Value must be greater than 0
end
```

## Field Definition

### Basic Fields

```ruby
class Product < Rbdantic::BaseModel
  field :id, Integer
  field :name, String
  field :price, Float
  field :active, Rbdantic::Boolean
end
```

### Default Values

```ruby
class Config < Rbdantic::BaseModel
  # Static default
  field :timeout, Integer, default: 30

  # Dynamic default (factory)
  field :created_at, Time, default_factory: -> { Time.now }

  # Optional field (can be nil)
  field :nickname, String, optional: true
end
```

### Field Constraints

#### String Constraints

```ruby
class User < Rbdantic::BaseModel
  field :username, String,
    min_length: 3,
    max_length: 20,
    pattern: /\A[a-zA-Z0-9_]+\z/
end
```

#### Numeric Constraints

```ruby
class Product < Rbdantic::BaseModel
  field :price, Float,
    gt: 0,        # greater than
    le: 10000     # less than or equal

  field :quantity, Integer,
    ge: 0,        # greater than or equal
    multiple_of: 1
end
```

#### Array Constraints

```ruby
class Order < Rbdantic::BaseModel
  field :items, [String],
    min_items: 1,
    max_items: 100,
    unique_items: true

end
```

### Custom Validators in Field

```ruby
class User < Rbdantic::BaseModel
  # Proc validator returning false on failure
  field :email, String,
    validators: [->(v) { v.include?("@") || false }]

  # Proc validator returning error message
  field :password, String,
    validators: [->(v) { v.length >= 8 ? nil : "Password must be at least 8 characters" }]
end
```

## Model Configuration

Use `model_config` to configure model behavior:

```ruby
class User < Rbdantic::BaseModel
  model_config(
    extra: :forbid,           # reject extra fields
    frozen: true,             # immutable after creation
    strict: true,             # strict type checking
    coerce_mode: :strict,     # no type coercion
    validate_assignment: true # validate on field assignment
  )

  field :name, String
end
```

### Configuration Options

| Option | Values | Description |
|--------|--------|-------------|
| `extra` | `:ignore`, `:forbid`, `:allow` | How to handle extra fields not defined |
| `frozen` | `true`, `false` | Make model immutable after initialization |
| `strict` | `true`, `false` | Strict type checking (no coercion) |
| `coerce_mode` | `:strict`, `:coerce` | Enable/disable type coercion |
| `validate_assignment` | `true`, `false` | Validate when assigning to fields |

### Extra Fields Behavior

```ruby
# Ignore extra fields (default)
class ModelA < Rbdantic::BaseModel
  model_config extra: :ignore
  field :name, String
end
ModelA.new(name: "test", extra: "data")  # extra field is dropped

# Forbid extra fields
class ModelB < Rbdantic::BaseModel
  model_config extra: :forbid
  field :name, String
end
ModelB.new(name: "test", extra: "data")  # raises ValidationError

# Allow extra fields
class ModelC < Rbdantic::BaseModel
  model_config extra: :allow
  field :name, String
end
m = ModelC.new(name: "test", extra: "data")
m[:extra]  # => "data"
```

## Validators

### Field Validators

Field validators run at different stages:

```ruby
class User < Rbdantic::BaseModel
  field :email, String

  # Before validation - can transform value
  field_validator :email, mode: :before do |value, ctx|
    value&.downcase
  end

  # After validation - validate transformed value
  field_validator :email, mode: :after do |value, ctx|
    raise "Invalid email format" unless value.include?("@")
    value
  end
end
```

#### Validator Modes

| Mode | Description |
|------|-------------|
| `:before` | Runs before type validation, can transform value |
| `:after` | Runs after type validation, validate the final value |
| `:plain` | Runs instead of type validation (skips type check) |
| `:wrap` | Runs after all other validators |

### Model Validators

Model validators validate the entire model:

```ruby
class Account < Rbdantic::BaseModel
  field :password, String
  field :confirm_password, String

  # Before validator - preprocess input data
  model_validator mode: :before do |data|
    data[:password] = data[:password]&.strip
    data
  end

  # After validator - validate model state
  model_validator mode: :after do |model|
    if model.password != model.confirm_password
      raise "Passwords do not match"
    end
  end
end
```

## Nested Models

Rbdantic supports nested models just like Pydantic, allowing you to build complex data structures with hierarchical validation.

### Single Nested Model

```ruby
class Address < Rbdantic::BaseModel
  field :street, String, min_length: 1
  field :city, String, min_length: 1
  field :zip_code, String, pattern: /\A\d{5}\z/
end

class User < Rbdantic::BaseModel
  field :name, String
  field :address, Address  # nested model type
end

# Create from hash - nested model is automatically validated
user = User.new(
  name: "Alice",
  address: {
    street: "123 Main St",
    city: "Boston",
    zip_code: "02134"
  }
)

puts user.address.class  # => Address
puts user.address.city   # => "Boston"

# Or pass a pre-built nested model instance
address = Address.new(street: "456 Oak Ave", city: "Cambridge", zip_code: "02139")
user = User.new(name: "Jane", address: address)

# Serialize - nested models are recursively dumped
user.model_dump
# => { name: "Jane", address: { street: "456 Oak Ave", city: "Cambridge", zip_code: "02139" } }
```

### Deeply Nested Models

You can nest models at any depth:

```ruby
class Country < Rbdantic::BaseModel
  field :code, String, pattern: /\A[A-Z]{2}\z/
  field :name, String
end

class City < Rbdantic::BaseModel
  field :name, String
  field :country, Country  # nested within nested
end

class Person < Rbdantic::BaseModel
  field :name, String
  field :birthplace, City  # two levels of nesting
end

# Create deeply nested structure
person = Person.new(
  name: "Alice",
  birthplace: {
    name: "Paris",
    country: {
      code: "FR",
      name: "France"
    }
  }
)

puts person.birthplace.country.code  # => "FR"
```

### Array of Nested Models

Use `[Type]` shorthand to validate arrays of nested models:

```ruby
class Item < Rbdantic::BaseModel
  field :name, String, min_length: 1
  field :quantity, Integer, gt: 0
  field :price, Float, ge: 0
end

class Order < Rbdantic::BaseModel
  field :order_id, String
  field :items, [Item], min_items: 1
end

# Create order with multiple items
order = Order.new(
  order_id: "ORD-001",
  items: [
    { name: "Widget", quantity: 5, price: 9.99 },
    { name: "Gadget", quantity: 2, price: 19.99 }
  ]
)

puts order.items[0].class  # => Item
puts order.items.length    # => 2

# Serialize - array items are recursively dumped
order.model_dump
# => { order_id: "ORD-001", items: [{ name: "Widget", quantity: 5, price: 9.99 }, ...] }
```

### Optional Nested Models

```ruby
class Profile < Rbdantic::BaseModel
  field :bio, String
  field :avatar_url, String
end

class User < Rbdantic::BaseModel
  field :name, String
  field :profile, Profile, optional: true  # can be nil
end

# Without profile
user = User.new(name: "Bob")
puts user.profile  # => nil

# With profile
user = User.new(name: "Bob", profile: { bio: "Developer", avatar_url: "..." })
puts user.profile.bio  # => "Developer"
```

### Nested Model Validation Errors

Errors in nested models include the full path:

```ruby
begin
  User.new(
    name: "Alice",
    address: {
      street: "",           # invalid: too short
      city: "Boston",
      zip_code: "invalid"   # invalid: pattern mismatch
    }
  )
rescue Rbdantic::ValidationError => e
  e.errors.each do |err|
    puts "#{err.loc.join('.')} - #{err.msg}"
  end
  # address.street - String must be at least 1 characters
  # address.zip_code - String does not match pattern ...
end

# Deeply nested error path
begin
  Person.new(
    name: "Bob",
    birthplace: {
      name: "London",
      country: { code: "invalid", name: "UK" }
    }
  )
rescue Rbdantic::ValidationError => e
  puts e.errors.first.loc  # => [:birthplace, :country, :code]
end

# Array item error path
begin
  Order.new(
    order_id: "ORD-001",
    items: [
      { name: "Widget", quantity: 5, price: 9.99 },
      { name: "", quantity: 0, price: -1 }  # invalid item at index 1
    ]
  )
rescue Rbdantic::ValidationError => e
  e.errors.each do |err|
    puts "#{err.loc.join('.')} - #{err.msg}"
  end
  # items.1.name - String must be at least 1 characters
  # items.1.quantity - Value must be greater than 0
  # items.1.price - Value must be greater than or equal to 0
end
```

### Self-Referencing Models

Models can reference themselves for recursive structures:

```ruby
class TreeNode < Rbdantic::BaseModel
  field :value, String
  field :children, [TreeNode], default_factory: -> { [] }
end

tree = TreeNode.new(
  value: "root",
  children: [
    { value: "child1", children: [{ value: "grandchild1" }] },
    { value: "child2" }
  ]
)

puts tree.children[0].children[0].value  # => "grandchild1"
```

## Inheritance

Fields, validators, and configuration are inherited:

```ruby
class Animal < Rbdantic::BaseModel
  field :name, String
  field :age, Integer, gt: 0

  model_config extra: :ignore
end

class Dog < Animal
  field :breed, String  # inherits name and age
end

class Cat < Animal
  model_config extra: :allow
end
```

**Note:** Child classes inherit parent `model_config` values and can override only the options they need.

## Serialization

### model_dump

Convert model to Hash with options:

```ruby
class User < Rbdantic::BaseModel
  field :name, String
  field :role, String, default: "user"
  field :active, Rbdantic::Boolean, default: true
end

user = User.new(name: "Alice")

# Full dump
user.model_dump
# => { name: "Alice", role: "user", active: true }

# Exclude fields with default values
user.model_dump(exclude_defaults: true)
# => { name: "Alice" }

# Include specific fields
user.model_dump(include: [:name])
# => { name: "Alice" }

# Exclude specific fields
user.model_dump(exclude: [:active])
# => { name: "Alice", role: "user" }

# Exclude unset fields (not provided during initialization)
user.model_dump(exclude_unset: true)
# => { name: "Alice" }
```

### model_dump_json

Convert to JSON string:

```ruby
user.model_dump_json
# => {"name":"Alice","role":"user","active":true}

# With indentation
user.model_dump_json(indent: 2)
# => {
#      "name": "Alice",
#      "role": "user",
#      "active": true
#    }
```

## JSON Schema Generation

Generate JSON Schema for API documentation:

```ruby
class User < Rbdantic::BaseModel
  field :id, Integer, gt: 0
  field :name, String, min_length: 1, max_length: 100
  field :email, String, pattern: /\A[^@\s]+@[^@\s]+\z/
  field :age, Integer, optional: true, ge: 0, le: 150
end

schema = User.model_json_schema
# => {
#   "$schema": "https://json-schema.org/draft/2020-12/schema",
#   "type": "object",
#   "title": "User",
#   "properties": {
#     "id": { "type": "integer", "exclusiveMinimum": 0 },
#     "name": { "type": "string", "minLength": 1, "maxLength": 100 },
#     "email": { "type": "string", "pattern": "^[^@\\s]+@[^@\\s]+$" },
#     "age": { "type": ["integer", "null"], "minimum": 0, "maximum": 150 }
#   },
#   "required": ["id", "name", "email"]
# }
```

## Type Coercion

Automatic type conversion when `coerce_mode: :coerce`:

```ruby
class Config < Rbdantic::BaseModel
  model_config coerce_mode: :coerce

  field :count, Integer
  field :price, Float
  field :enabled, Rbdantic::Boolean
end

config = Config.new(
  count: "42",       # coerced to 42
  price: "19.99",    # coerced to 19.99
  enabled: "yes"     # coerced to true
)

config.count   # => 42 (Integer)
config.price   # => 19.99 (Float)
config.enabled # => true
```

### Supported Coercions

| Target Type | Source Examples |
|-------------|-----------------|
| `String` | Any value with `to_s` |
| `Integer` | `"42"`, `42.0` |
| `Float` | `"3.14"`, `42` |
| `Rbdantic::Boolean` | `"true"`, `"yes"`, `"on"`, `"1"`, `1`, `"false"`, `"no"`, `"off"`, `"0"`, `0` |
| `Array` | String with `split`, any value with `to_a` |
| `Hash` | Array of pairs, any value with `to_h` |
| `Time` | ISO8601 String, `Date`, `DateTime`, Unix timestamp (Integer/Float) |
| `Date` | ISO8601 String, `Time`, `DateTime`, days since epoch (Integer/Float) |
| `DateTime` | ISO8601 String, `Time`, `Date`, Unix timestamp (Integer/Float) |

## Validation Errors

ValidationError provides detailed error information:

```ruby
begin
  User.new(name: "", age: -1)
rescue Rbdantic::ValidationError => e
  e.error_count  # => 2
  e.errors       # => Array of ErrorDetail
  e.as_json      # => { errors: [...], error_count: 2 }
  e.to_h         # => same as as_json

  e.errors.each do |err|
    err.type   # => :string_too_short, :value_not_greater_than
    err.loc    # => [:name], [:age]  (location path)
    err.msg    # => "String must be at least..."
    err.input  # => ""  (original input value)
  end
end
```

## Supported Types

| Type | Notes |
|------|-------|
| `String` | Built-in string type |
| `Integer` | Built-in integer type |
| `Float` | Built-in float type |
| `Rbdantic::Boolean` | Boolean field accepting true/false |
| `Symbol` | Ruby symbol, max length 256 chars (DoS protection) |
| `[Type]` | Array with per-item validation |
| `Hash` | Key-value hash type |
| `Time` | Ruby Time type |
| `Date` | Ruby Date type |
| `DateTime` | Ruby DateTime type |
| `Rbdantic::BaseModel` subclass | Nested model validation |

## Format Validation

Built-in format validators for common patterns:

```ruby
class User < Rbdantic::BaseModel
  field :email, String, format: :email    # Basic email validation
  field :website, String, format: :uri    # URI validation (http/https)
end
```

| Format | Pattern |
|--------|---------|
| `:email` | Basic email check (user@domain) |
| `:uri` | HTTP/HTTPS URI |

For complex validation, use custom `pattern` regex or `field_validator`.

## Limitations & Security

### Security Limits

| Limit | Value | Purpose |
|-------|-------|---------|
| Symbol max length | 256 chars | Prevent Symbol DoS attacks |
| Nested model depth | ~20 levels | Prevent stack overflow |

These limits protect against malicious input that could exhaust memory or cause stack overflow.

### Thread Safety

Models are thread-safe for read operations after initialization. However:

- Validation during initialization is not thread-safe (uses internal state)
- `validate_assignment` mode uses instance-level locking
- Avoid sharing model instances across threads during mutation

## Differences from Pydantic

| Feature | Pydantic | Rbdantic |
|---------|----------|----------|
| Field aliases | `Field(alias="name")` | `alias_name:` plus `by_alias: true` |
| Computed fields | `@computed_field` | Not supported |
| Generic models | `BaseModel[T]` | Not supported |
| Field serialization alias | `serialization_alias` | Uses `alias_name:` and dump/schema `by_alias:` |
| Model copy/update | `model.copy(update={})` | `copy(deep:)` and `update(**data)` helpers |
| Discriminated unions | `Annotated[Union, Field(discriminator)]` | Not supported |
| Custom type adapters | `TypeAdapter` | Use validators instead |
| Boolean type | `bool` | `Rbdantic::Boolean` |
| Config class | `BaseModelConfig` | `model_config` hash |

### API Naming Differences

| Pydantic | Rbdantic |
|----------|----------|
| `Field()` | `field :name, Type, **options` |
| `@field_validator` | `field_validator :name, mode: ...` |
| `@model_validator` | `model_validator mode: ...` |
| `model_config = ConfigDict(...)` | `model_config(...)` |
| `model_dump()` | `model_dump()` |
| `model_dump_json()` | `model_dump_json()` |
| `model_validate()` | `Model.model_validate(data)` |

## Requirements

- Ruby >= 2.7 (for keyword arguments and pattern matching)
- No external dependencies (pure Ruby implementation)

## Error Handling Best Practices

### Catching Specific Field Errors

```ruby
begin
  User.new(name: "", email: "invalid")
rescue Rbdantic::ValidationError => e
  # Find errors for specific field
  name_errors = e.errors.select { |err| err.loc.first == :name }
  puts "Name errors: #{name_errors.map(&:msg).join(', ')}"

  # Group errors by field
  errors_by_field = e.errors.group_by { |err| err.loc.first }
  errors_by_field.each do |field, errs|
    puts "#{field}: #{errs.map(&:msg).join(', ')}"
  end
end
```

### Custom Error Messages

Use `field_validator` for custom messages:

```ruby
class User < Rbdantic::BaseModel
  field :password, String

  field_validator :password, mode: :after do |value, ctx|
    if value.length < 8
      raise Rbdantic::ValidationError::ErrorDetail.new(
        type: :password_too_short,
        loc: [:password],
        msg: "Password must be at least 8 characters (got #{value.length})",
        input: value
      )
    end
    value
  end
end
```

### Error JSON for APIs

```ruby
rescue Rbdantic::ValidationError => e
  # Return as JSON for API responses
  status 400
  json e.as_json
  # => { "errors": [...], "error_count": 2 }
```

## API Reference

### Rbdantic::BaseModel

| Method | Description |
|--------|-------------|
| `field(name, type, **options)` | Define a field with type and constraints |
| `model_config(**options)` | Configure model behavior |
| `field_validator(name, mode:, &block)` | Define a field-level validator |
| `model_validator(mode:, &block)` | Define a model-level validator |
| `model_json_schema(**options)` | Generate JSON Schema |
| `model_fields` | Returns hash of field definitions |
| `model_config` | Returns model configuration |
| `inherited(subclass)` | Hook for inheritance (internal) |

### Instance Methods

| Method | Description |
|--------|-------------|
| `initialize(data = {})` | Create model with validation |
| `model_dump(**options)` | Convert to Hash |
| `to_h` | Alias for `model_dump` |
| `model_dump_json(indent: nil)` | Convert to JSON string |
| `[name]` | Bracket access for field value |
| `[name] = value` | Bracket assignment for field value |

### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `default` | Any | Static default value |
| `default_factory` | Proc | Dynamic default value generator |
| `optional` | Boolean | Allow nil values |
| `required` | Boolean | Set to `false` to allow nil (same as `optional: true`) |
| `validators` | Array | Custom validator Procs |
| `alias_name` | Symbol | Alternative name for input/output (use with `by_alias: true`) |
| `format` | Symbol | Built-in format validator (`:email`, `:uri`, `:uuid`) |
| `min_length` | Integer | Minimum string length |
| `max_length` | Integer | Maximum string length |
| `pattern` | Regexp | String pattern match |
| `gt` | Numeric | Greater than |
| `ge` | Numeric | Greater than or equal |
| `lt` | Numeric | Less than |
| `le` | Numeric | Less than or equal |
| `multiple_of` | Numeric | Must be multiple of |
| `min_items` | Integer | Minimum array items |
| `max_items` | Integer | Maximum array items |
| `unique_items` | Boolean | Array items must be unique |

## Development

After checking out the repo:

```bash
bin/setup        # Install dependencies
rake spec        # Run tests
bin/console      # Interactive prompt
bundle exec rake install  # Install gem locally
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Inspiration

This library is inspired by [Pydantic](https://github.com/pydantic/pydantic) - the excellent Python data validation library.

## Development Notes

This library was primarily developed with AI assistance (Claude), demonstrating how AI tools can accelerate software development while maintaining code quality and comprehensive testing.
