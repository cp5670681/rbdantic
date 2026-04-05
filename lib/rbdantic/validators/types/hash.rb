# frozen_string_literal: true

require "json"
require_relative "base"

module Rbdantic
  module Validators
    module Types
      class Hash < Base
        def matches_type?(value)
          value.is_a?(::Hash)
        end

        def expected_type_name
          "Hash"
        end

        def validate_constraints(value, errors, location, strict: false)
          validate_size(value, errors, location)
          value
        end

        def coerce(value)
          case value
          when ::Hash then value
          when ::Array
            value.to_h if value.all? { |item| item.is_a?(::Array) && item.length == 2 }
          when ::String
            begin
              parsed = JSON.parse(value)
              parsed if parsed.is_a?(::Hash)
            rescue JSON::ParserError; nil
            end
          else
            value.to_h if value.respond_to?(:to_h)
          end
        end

        private

        def validate_size(value, errors, location)
          if constraints[:min_properties] && value.length < constraints[:min_properties]
            errors << error(type: :hash_too_few_properties, loc: location, 
                            msg: "Hash must have at least #{constraints[:min_properties]} properties", input: value)
          end
          if constraints[:max_properties] && value.length > constraints[:max_properties]
            errors << error(type: :hash_too_many_properties, loc: location, 
                            msg: "Hash must have at most #{constraints[:max_properties]} properties", input: value)
          end
        end
      end
    end
  end
end