# frozen_string_literal: true

require "json"
require_relative "base"

module Rbdantic
  module Validators
    module Types
      class Array < Base
        attr_reader :element_type, :item_validator

        def initialize(element_type: nil, **constraints)
          super(**constraints)
          @element_type = element_type
          @item_validator = Types.create_validator(element_type) if element_type
        end

        def matches_type?(value)
          value.is_a?(::Array)
        end

        def expected_type_name
          "Array"
        end

        def validate_constraints(value, errors, location, strict: false)
          validate_length(value, errors, location)
          validate_unique(value, errors, location)
          validate_items(value, errors, location, strict: strict)
        end

        def coerce(value)
          case value
          when ::String
            begin
              parsed = JSON.parse(value)
              parsed if parsed.is_a?(::Array)
            rescue JSON::ParserError; nil
            end
          else
            value.respond_to?(:to_a) ? value.to_a : nil
          end
        end

        private

        def validate_length(value, errors, location)
          if constraints[:min_items] && value.length < constraints[:min_items]
            errors << error(type: :array_too_short, loc: location, 
                            msg: "Array must have at least #{constraints[:min_items]} items", input: value)
          end
          if constraints[:max_items] && value.length > constraints[:max_items]
            errors << error(type: :array_too_long, loc: location, 
                            msg: "Array must have at most #{constraints[:max_items]} items", input: value)
          end
        end

        def validate_unique(value, errors, location)
          if constraints[:unique_items] && value.uniq.length != value.length
            errors << error(type: :array_items_not_unique, loc: location, msg: "Array items must be unique", 
                            input: value)
          end
        end

        def validate_items(value, errors, location, strict: false)
          return value unless @item_validator

          value.map.with_index do |item, index|
            item_errors, coerced_item = @item_validator.validate(item, location + [index], strict: strict)
            errors.concat(item_errors)
            coerced_item
          end
        end
      end
    end
  end
end
