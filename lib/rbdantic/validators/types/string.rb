# frozen_string_literal: true

require_relative "base"

module Rbdantic
  module Validators
    module Types
      class String < Base
        FORMAT_PATTERNS = {
          email: /\A[^@\s]+@[^@\s]+\z/,
          uri: /\A[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^\s]+\z/,
          uuid: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
        }.freeze

        def matches_type?(value)
          value.is_a?(::String)
        end

        def expected_type_name
          "String"
        end

        def coerce(value)
          case value
          when ::String then value
          when ::Symbol, Numeric, TrueClass, FalseClass then value.to_s
          else nil
          end
        end

        def validate_constraints(value, errors, location, strict: false)
          validate_length(value, errors, location)
          validate_pattern(value, errors, location)
          validate_format(value, errors, location)
          value
        end

        private

        def validate_length(value, errors, location)
          if constraints[:min_length] && value.length < constraints[:min_length]
            errors << error(type: :string_too_short, loc: location, 
                            msg: "String must be at least #{constraints[:min_length]} characters", input: value)
          end

          if constraints[:max_length] && value.length > constraints[:max_length]
            errors << error(type: :string_too_long, loc: location, 
                            msg: "String must be at most #{constraints[:max_length]} characters", input: value)
          end
        end

        def validate_pattern(value, errors, location)
          if constraints[:pattern] && !constraints[:pattern].match?(value)
            errors << error(type: :string_pattern_mismatch, loc: location, 
                            msg: "String does not match pattern #{constraints[:pattern].source}", input: value)
          end
        end

        def validate_format(value, errors, location)
          if constraints[:format] && FORMAT_PATTERNS.key?(constraints[:format])
            unless FORMAT_PATTERNS[constraints[:format]].match?(value)
              errors << error(type: :string_format_mismatch, loc: location, 
                              msg: "String does not match format '#{constraints[:format]}'", input: value)
            end
          end
        end
      end
    end
  end
end