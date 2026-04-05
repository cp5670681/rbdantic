# frozen_string_literal: true

require "json"
require "set"

require_relative "error_detail"
require_relative "field"
require_relative "config"
require_relative "serialization/dumper"
require_relative "serialization/json_serializer"
require_relative "json_schema/generator"
require_relative "json_schema/types"
require_relative "json_schema/defs_registry"
require_relative "validators/field_validator"
require_relative "validators/model_validator"
require_relative "validators/validator_context"
require_relative "validators/types"
require_relative "base/dsl"
require_relative "base/validation"
require_relative "base/access"

module Rbdantic
  # Base class for data models with field DSL and validation
  # Similar to Pydantic BaseModel in Python
  class BaseModel
    include DSL
    include Validation
    include Access
  end
end
