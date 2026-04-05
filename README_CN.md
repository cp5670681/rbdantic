# Rbdantic

**Ruby 数据验证与设置管理** - 一个受 Pydantic 启发的 Ruby 数据验证库。

Rbdantic 将 Pydantic 强大的数据验证能力引入 Ruby,提供运行时数据验证、序列化和 JSON Schema 生成,配合直观的 DSL 语法。

[English Documentation](README.md)

## 功能特性

- **基础模型类** - 定义带有类型检查字段的数据模型
- **字段约束** - 内置字符串、数字和数组约束
- **自定义验证器** - 支持多种模式的字段级和模型级验证器
- **类型强制转换** - 可配置严格程度的自动类型转换
- **嵌套模型** - 支持嵌套模型验证
- **模型继承** - 子类继承字段和验证器
- **模型配置** - 灵活的配置选项(额外字段、冻结模型等)
- **序列化** - 支持过滤选项的 Hash 或 JSON 转换
- **JSON Schema 生成** - 自动生成 API 文档所需的 JSON Schema
- **详细错误报告** - 带位置路径的结构化验证错误

## 安装

添加到 Gemfile:

```ruby
gem 'rbdantic'
```

或直接安装:

```bash
gem install rbdantic
```

## 快速入门

```ruby
require 'rbdantic'

class User < Rbdantic::BaseModel
  field :name, String, min_length: 1, max_length: 100
  field :email, String, pattern: /\A[^@\s]+@[^@\s]+\z/
  field :age, Integer, gt: 0, le: 150
  field :tags, [String], default_factory: -> { [] }
end

# 创建有效用户
user = User.new(
  name: "Alice",
  email: "alice@example.com",
  age: 30
)

puts user.name   # => "Alice"
puts user.age    # => 30
puts user.tags   # => []

# 序列化为 Hash
puts user.model_dump
# => { name: "Alice", email: "alice@example.com", age: 30, tags: [] }

# to_h 是 model_dump 的别名
puts user.to_h
# => { name: "Alice", email: "alice@example.com", age: 30, tags: [] }

# 序列化为 JSON
puts user.model_dump_json
# => {"name":"Alice","email":"alice@example.com","age":30,"tags":[]}

# 验证错误
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

## 字段定义

### 基本字段

```ruby
class Product < Rbdantic::BaseModel
  field :id, Integer
  field :name, String
  field :price, Float
  field :active, Rbdantic::Boolean
end
```

### 默认值

```ruby
class Config < Rbdantic::BaseModel
  # 静态默认值
  field :timeout, Integer, default: 30

  # 动态默认值(工厂)
  field :created_at, Time, default_factory: -> { Time.now }

  # 可选字段(可以为 nil)
  field :nickname, String, optional: true
end
```

### 字段约束

#### 字符串约束

```ruby
class User < Rbdantic::BaseModel
  field :username, String,
    min_length: 3,
    max_length: 20,
    pattern: /\A[a-zA-Z0-9_]+\z/
end
```

#### 数字约束

```ruby
class Product < Rbdantic::BaseModel
  field :price, Float,
    gt: 0,        # 大于
    le: 10000     # 小于或等于

  field :quantity, Integer,
    ge: 0,        # 大于或等于
    multiple_of: 1
end
```

#### 数组约束

```ruby
class Order < Rbdantic::BaseModel
  field :items, [String],
    min_items: 1,
    max_items: 100,
    unique_items: true

end
```

### 字段内自定义验证器

```ruby
class User < Rbdantic::BaseModel
  # Proc 验证器,返回 false 表示失败
  field :email, String,
    validators: [->(v) { v.include?("@") || false }]

  # Proc 验证器,返回错误消息
  field :password, String,
    validators: [->(v) { v.length >= 8 ? nil : "密码长度至少8个字符" }]
end
```

## 模型配置

使用 `model_config` 配置模型行为:

```ruby
class User < Rbdantic::BaseModel
  model_config(
    extra: :forbid,           # 拒绝额外字段
    frozen: true,             # 创建后不可变
    strict: true,             # 严格类型检查
    coerce_mode: :strict,     # 不进行类型转换
    validate_assignment: true # 字段赋值时验证
  )

  field :name, String
end
```

### 配置选项

| 选项 | 可选值 | 说明 |
|------|--------|------|
| `extra` | `:ignore`, `:forbid`, `:allow` | 如何处理未定义的额外字段 |
| `frozen` | `true`, `false` | 初始化后冻结模型使其不可变 |
| `strict` | `true`, `false` | 严格类型检查(不转换类型) |
| `coerce_mode` | `:strict`, `:coerce` | 启用/禁用类型强制转换 |
| `validate_assignment` | `true`, `false` | 字段赋值时进行验证 |

### 额外字段行为

```ruby
# 忽略额外字段(默认)
class ModelA < Rbdantic::BaseModel
  model_config extra: :ignore
  field :name, String
end
ModelA.new(name: "test", extra: "data")  # extra 字段被丢弃

# 禁止额外字段
class ModelB < Rbdantic::BaseModel
  model_config extra: :forbid
  field :name, String
end
ModelB.new(name: "test", extra: "data")  # 抛出 ValidationError

# 允许额外字段
class ModelC < Rbdantic::BaseModel
  model_config extra: :allow
  field :name, String
end
m = ModelC.new(name: "test", extra: "data")
m[:extra]  # => "data"
```

## 验证器

### 字段验证器

字段验证器在不同阶段运行:

```ruby
class User < Rbdantic::BaseModel
  field :email, String

  # 验证前 - 可转换值
  field_validator :email, mode: :before do |value, ctx|
    value&.downcase
  end

  # 验证后 - 验证转换后的值
  field_validator :email, mode: :after do |value, ctx|
    raise "邮箱格式无效" unless value.include?("@")
    value
  end
end
```

#### 验证器模式

| 模式 | 说明 |
|------|------|
| `:before` | 类型验证前运行,可转换值 |
| `:after` | 类型验证后运行,验证最终值 |
| `:plain` | 替代类型验证运行(跳过类型检查) |
| `:wrap` | 所有其他验证器之后运行 |

### 模型验证器

模型验证器验证整个模型:

```ruby
class Account < Rbdantic::BaseModel
  field :password, String
  field :confirm_password, String

  # 前置验证器 - 预处理输入数据
  model_validator mode: :before do |data|
    data[:password] = data[:password]&.strip
    data
  end

  # 后置验证器 - 验证模型状态
  model_validator mode: :after do |model|
    if model.password != model.confirm_password
      raise "密码不匹配"
    end
  end
end
```

## 嵌套模型

Rbdantic 像 Pydantic 一样支持嵌套模型,让你可以构建带有层级验证的复杂数据结构。

### 单层嵌套模型

```ruby
class Address < Rbdantic::BaseModel
  field :street, String, min_length: 1
  field :city, String, min_length: 1
  field :zip_code, String, pattern: /\A\d{5}\z/
end

class User < Rbdantic::BaseModel
  field :name, String
  field :address, Address  # 嵌套模型类型
end

# 从哈希创建 - 嵌套模型自动验证
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

# 或传入已构建的嵌套模型实例
address = Address.new(street: "456 Oak Ave", city: "Cambridge", zip_code: "02139")
user = User.new(name: "Jane", address: address)

# 序列化 - 嵌套模型递归输出
user.model_dump
# => { name: "Jane", address: { street: "456 Oak Ave", city: "Cambridge", zip_code: "02139" } }
```

### 多层嵌套模型

可以任意深度嵌套模型:

```ruby
class Country < Rbdantic::BaseModel
  field :code, String, pattern: /\A[A-Z]{2}\z/
  field :name, String
end

class City < Rbdantic::BaseModel
  field :name, String
  field :country, Country  # 嵌套中的嵌套
end

class Person < Rbdantic::BaseModel
  field :name, String
  field :birthplace, City  # 两层嵌套
end

# 创建多层嵌套结构
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

### 嵌套模型数组

使用 `[Type]` 简写验证嵌套模型数组:

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

# 创建包含多个商品的订单
order = Order.new(
  order_id: "ORD-001",
  items: [
    { name: "Widget", quantity: 5, price: 9.99 },
    { name: "Gadget", quantity: 2, price: 19.99 }
  ]
)

puts order.items[0].class  # => Item
puts order.items.length    # => 2

# 序列化 - 数组元素递归输出
order.model_dump
# => { order_id: "ORD-001", items: [{ name: "Widget", quantity: 5, price: 9.99 }, ...] }
```

### 可选嵌套模型

```ruby
class Profile < Rbdantic::BaseModel
  field :bio, String
  field :avatar_url, String
end

class User < Rbdantic::BaseModel
  field :name, String
  field :profile, Profile, optional: true  # 可以是 nil
end

# 不带 profile
user = User.new(name: "Bob")
puts user.profile  # => nil

# 带 profile
user = User.new(name: "Bob", profile: { bio: "Developer", avatar_url: "..." })
puts user.profile.bio  # => "Developer"
```

### 嵌套模型验证错误

嵌套模型中的错误包含完整路径:

```ruby
begin
  User.new(
    name: "Alice",
    address: {
      street: "",           # 无效: 太短
      city: "Boston",
      zip_code: "invalid"   # 无效: 模式不匹配
    }
  )
rescue Rbdantic::ValidationError => e
  e.errors.each do |err|
    puts "#{err.loc.join('.')} - #{err.msg}"
  end
  # address.street - String must be at least 1 characters
  # address.zip_code - String does not match pattern ...
end

# 多层嵌套错误路径
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

# 数组元素错误路径
begin
  Order.new(
    order_id: "ORD-001",
    items: [
      { name: "Widget", quantity: 5, price: 9.99 },
      { name: "", quantity: 0, price: -1 }  # 索引1处的无效元素
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

### 自引用模型

模型可以引用自身实现递归结构:

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

## 继承

字段、验证器和配置均可继承:

```ruby
class Animal < Rbdantic::BaseModel
  field :name, String
  field :age, Integer, gt: 0

  model_config extra: :ignore
end

class Dog < Animal
  field :breed, String  # 继承 name 和 age
end

class Cat < Animal
  model_config extra: :allow
end
```

**注意：** 子类会继承父类的 `model_config`，只需要覆盖想修改的配置项。

## 序列化

### model_dump

将模型转换为 Hash,支持多种选项:

```ruby
class User < Rbdantic::BaseModel
  field :name, String
  field :role, String, default: "user"
  field :active, Rbdantic::Boolean, default: true
end

user = User.new(name: "Alice")

# 完整输出
user.model_dump
# => { name: "Alice", role: "user", active: true }

# 排除默认值字段
user.model_dump(exclude_defaults: true)
# => { name: "Alice" }

# 只包含指定字段
user.model_dump(include: [:name])
# => { name: "Alice" }

# 排除指定字段
user.model_dump(exclude: [:active])
# => { name: "Alice", role: "user" }

# 排除未设置字段(初始化时未提供的)
user.model_dump(exclude_unset: true)
# => { name: "Alice" }
```

### model_dump_json

转换为 JSON 字符串:

```ruby
user.model_dump_json
# => {"name":"Alice","role":"user","active":true}

# 带缩进
user.model_dump_json(indent: 2)
# => {
#      "name": "Alice",
#      "role": "user",
#      "active": true
#    }
```

## JSON Schema 生成

为 API 文档自动生成 JSON Schema:

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

## 类型强制转换

当设置 `coerce_mode: :coerce` 时自动进行类型转换:

```ruby
class Config < Rbdantic::BaseModel
  model_config coerce_mode: :coerce

  field :count, Integer
  field :price, Float
  field :enabled, Rbdantic::Boolean
end

config = Config.new(
  count: "42",       # 转换为 42
  price: "19.99",    # 转换为 19.99
  enabled: "yes"     # 转换为 true
)

config.count   # => 42 (Integer)
config.price   # => 19.99 (Float)
config.enabled # => true
```

### 支持的类型转换

| 目标类型 | 源示例 |
|----------|--------|
| `String` | 任何有 `to_s` 方法的值 |
| `Integer` | `"42"`, `42.0` |
| `Float` | `"3.14"`, `42` |
| `Rbdantic::Boolean` | `"true"`, `"yes"`, `"on"`, `"1"`, `1`, `"false"`, `"no"`, `"off"`, `"0"`, `0` |
| `Array` | 可用 `split` 分割的字符串,任何有 `to_a` 方法的值 |
| `Hash` | 键值对数组,任何有 `to_h` 方法的值 |

## 验证错误

ValidationError 提供详细的错误信息:

```ruby
begin
  User.new(name: "", age: -1)
rescue Rbdantic::ValidationError => e
  e.error_count  # => 2
  e.errors       # => ErrorDetail 数组
  e.as_json      # => { errors: [...], error_count: 2 }
  e.to_h         # => 同 as_json

  e.errors.each do |err|
    err.type   # => :string_too_short, :value_not_greater_than
    err.loc    # => [:name], [:age]  (位置路径)
    err.msg    # => "String must be at least..."
    err.input  # => ""  (原始输入值)
  end
end
```

## 支持的类型

| 类型 | 说明 |
|------|------|
| `String` | 内置字符串类型 |
| `Integer` | 内置整数类型 |
| `Float` | 内置浮点数类型 |
| `Rbdantic::Boolean` | 布尔字段，接受 true/false |
| `Symbol` | Ruby 符号，最大长度 256 字符（防止 DoS 攻击） |
| `[Type]` | 带元素校验的数组 |
| `Hash` | 键值哈希类型 |
| `Time` | Ruby Time 类型 |
| `Rbdantic::BaseModel` 子类 | 嵌套模型验证 |

**注意：** 对外布尔字段统一使用 `Rbdantic::Boolean`。

```ruby
class Config < Rbdantic::BaseModel
  field :enabled, Rbdantic::Boolean
  field :active, Rbdantic::Boolean, optional: true
end
```

## 格式验证

内置常用格式的验证器：

```ruby
class User < Rbdantic::BaseModel
  field :email, String, format: :email    # 基础邮箱验证
  field :website, String, format: :uri    # URI 验证 (http/https)
end
```

| 格式 | 模式 |
|------|------|
| `:email` | 基础邮箱检查 (user@domain) |
| `:uri` | HTTP/HTTPS URI |

复杂验证请使用自定义 `pattern` 正则或 `field_validator`。

## 限制与安全

### 安全限制

| 限制 | 值 | 目的 |
|------|-----|------|
| Symbol 最大长度 | 256 字符 | 防止 Symbol DoS 攻击 |
| 嵌套模型深度 | ~20 层 | 防止栈溢出 |

这些限制防止恶意输入耗尽内存或导致栈溢出。

### 线程安全

模型初始化后的读取操作是线程安全的。但需注意：

- 初始化过程中的验证不是线程安全的（使用内部状态）
- `validate_assignment` 模式使用实例级锁
- 变更期间避免跨线程共享模型实例

## 与 Pydantic 的差异

| 功能 | Pydantic | Rbdantic |
|------|----------|----------|
| 字段别名 | `Field(alias="name")` | `alias_name:` 配合 `by_alias: true` |
| 计算字段 | `@computed_field` | 不支持 |
| 泛型模型 | `BaseModel[T]` | 不支持 |
| 序列化别名 | `serialization_alias` | 使用 `alias_name:` 与 dump/schema 的 `by_alias:` |
| 模型复制/更新 | `model.copy(update={})` | 提供 `copy(deep:)` 与 `update(**data)` 辅助方法 |
| 判断联合类型 | `Annotated[Union, Field(discriminator)]` | 不支持 |
| 自定义类型适配器 | `TypeAdapter` | 使用验证器替代 |
| 布尔类型 | `bool` | `Rbdantic::Boolean` |
| 配置类 | `BaseModelConfig` | `model_config` 哈希 |

### API 命名差异

| Pydantic | Rbdantic |
|----------|----------|
| `Field()` | `field :name, Type, **options` |
| `@field_validator` | `field_validator :name, mode: ...` |
| `@model_validator` | `model_validator mode: ...` |
| `model_config = ConfigDict(...)` | `model_config(...)` |
| `model_dump()` | `model_dump()` |
| `model_dump_json()` | `model_dump_json()` |
| `model_validate()` | `Model.model_validate(data)` |

## 系统要求

- Ruby >= 2.7（支持关键字参数和模式匹配）
- 无外部依赖（纯 Ruby 实现）

## 错误处理最佳实践

### 捕获特定字段错误

```ruby
begin
  User.new(name: "", email: "invalid")
rescue Rbdantic::ValidationError => e
  # 查找特定字段的错误
  name_errors = e.errors.select { |err| err.loc.first == :name }
  puts "名称错误: #{name_errors.map(&:msg).join(', ')}"

  # 按字段分组错误
  errors_by_field = e.errors.group_by { |err| err.loc.first }
  errors_by_field.each do |field, errs|
    puts "#{field}: #{errs.map(&:msg).join(', ')}"
  end
end
```

### 自定义错误消息

使用 `field_validator` 自定义消息：

```ruby
class User < Rbdantic::BaseModel
  field :password, String

  field_validator :password, mode: :after do |value, ctx|
    if value.length < 8
      raise Rbdantic::ValidationError::ErrorDetail.new(
        type: :password_too_short,
        loc: [:password],
        msg: "密码至少需要8个字符（当前#{value.length}个）",
        input: value
      )
    end
    value
  end
end
```

### API 错误 JSON 响应

```ruby
rescue Rbdantic::ValidationError => e
  # 返回 JSON 用于 API 响应
  status 400
  json e.as_json
  # => { "errors": [...], "error_count": 2 }
```

## API 参考

### Rbdantic::BaseModel 类方法

| 方法 | 说明 |
|------|------|
| `field(name, type, **options)` | 定义字段及其类型和约束 |
| `model_config(**options)` | 配置模型行为 |
| `field_validator(name, mode:, &block)` | 定义字段级验证器 |
| `model_validator(mode:, &block)` | 定义模型级验证器 |
| `model_json_schema(**options)` | 生成 JSON Schema |
| `model_fields` | 返回字段定义哈希 |
| `model_config` | 返回模型配置 |
| `inherited(subclass)` | 继承钩子(内部使用) |

### 实例方法

| 方法 | 说明 |
|------|------|
| `initialize(data = {})` | 创建并验证模型 |
| `model_dump(**options)` | 转换为 Hash |
| `to_h` | `model_dump` 的别名 |
| `model_dump_json(indent: nil)` | 转换为 JSON 字符串 |
| `[name]` | 括号访问字段值 |
| `[name] = value` | 括号赋值字段值 |

### 字段选项

| 选项 | 类型 | 说明 |
|------|------|------|
| `default` | Any | 静态默认值 |
| `default_factory` | Proc | 动态默认值生成器 |
| `optional` | Boolean | 允许 nil 值 |
| `required` | Boolean | 设为 `false` 允许 nil（等同于 `optional: true`） |
| `validators` | Array | 自定义验证器 Proc |
| `alias_name` | Symbol | 输入/输出的替代名称（配合 `by_alias: true` 使用） |
| `format` | Symbol | 内置格式验证器（`:email`、`:uri`、`:uuid`） |
| `min_length` | Integer | 字符串最小长度 |
| `max_length` | Integer | 字符串最大长度 |
| `pattern` | Regexp | 字符串正则匹配 |
| `gt` | Numeric | 大于 |
| `ge` | Numeric | 大于或等于 |
| `lt` | Numeric | 小于 |
| `le` | Numeric | 小于或等于 |
| `multiple_of` | Numeric | 必须是该数的倍数 |
| `min_items` | Integer | 数组最小元素数 |
| `max_items` | Integer | 数组最大元素数 |
| `unique_items` | Boolean | 数组元素必须唯一 |

## 开发

检出仓库后:

```bash
bin/setup        # 安装依赖
rake spec        # 运行测试
bin/console      # 交互式提示
bundle exec rake install  # 本地安装 gem
```

## 贡献

欢迎提交 Bug 报告和 Pull Request。

## 许可证

本 gem 基于 [MIT 许可证](https://opensource.org/licenses/MIT) 开源。

## 致谢

本库受 [Pydantic](https://github.com/pydantic/pydantic) 启发 - 优秀的 Python 数据验证库。

## 开发说明

本库主要由 AI (Claude) 协助开发，展示了 AI 工具如何加速软件开发，同时保持代码质量和全面测试。
