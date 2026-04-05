# frozen_string_literal: true

require_relative "types/base"
require_relative "types/number"
require_relative "types/string"
require_relative "types/integer"
require_relative "types/float"
require_relative "types/boolean"
require_relative "types/array"
require_relative "types/hash"
require_relative "types/symbol"
require_relative "types/time"
require_relative "types/model"

module Rbdantic
  # Marker class for boolean type validation (since Ruby has TrueClass and FalseClass)
  class Boolean; end

  module Validators
    module Types
      VALIDATOR_CLASSES = {
        ::String => Validators::Types::String,
        ::Integer => Validators::Types::Integer,
        ::Float => Validators::Types::Float,
        Rbdantic::Boolean => Validators::Types::Boolean,
        ::Array => Validators::Types::Array,
        ::Hash => Validators::Types::Hash,
        ::Symbol => Validators::Types::Symbol,
        ::Time => Validators::Types::Time
      }.freeze

      def self.validator_class_for(type)
        VALIDATOR_CLASSES[type]
      end

      # Create validator for type with constraints
      # @param type [Class] the field type
      # @param constraints [Hash] constraint options (min_length, gt, etc.)
      # @return [Base, nil] validator instance
      def self.create_validator(type, **constraints)
        return nil if type.nil?

        if nested_model?(type)
          return Validators::Types::Model.new(type, **constraints)
        end

        validator_class = VALIDATOR_CLASSES[type]
        raise ArgumentError, "Unsupported field type: #{type}" unless validator_class

        validator_class.new(**constraints)
      end

      def self.has_validator?(type)
        VALIDATOR_CLASSES.key?(type)
      end

      # Check if type is a nested model
      def self.nested_model?(type)
        type.is_a?(Class) && type < Rbdantic::BaseModel && !type.equal?(Rbdantic::BaseModel)
      end
    end
  end
end
