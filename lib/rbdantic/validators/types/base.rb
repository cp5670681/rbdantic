# frozen_string_literal: true

module Rbdantic
  module Validators
    module Types
      # Base class for type validators
      # Provides common validation pattern with type checking and coercion
      class Base
        attr_reader :constraints

        def initialize(**constraints)
          @constraints = constraints
        end

        # Main validation entry point
        # @return [Array<ErrorDetail>, value] tuple of errors and validated/coerced value
        def validate(value, location = [], strict: false)
          errors = []

          # Type check with optional coercion
          unless matches_type?(value)
            if !strict && !(coerced = coerce(value)).nil?
              value = coerced
            else
              errors << type_error(value, location)
              return [errors, value]
            end
          end

          # Constraint validation (override in subclasses)
          # Returns potentially transformed value (e.g., for nested type coercion)
          value = validate_constraints(value, errors, location, strict: strict)

          [errors, value]
        end

        # Override in subclasses to define type matching
        # @return [Boolean] true if value matches expected type
        def matches_type?(value)
          raise NotImplementedError, "Type validators must implement #matches_type?"
        end

        # Override in subclasses to define coercion logic
        # @return [Object, nil] coerced value or nil if cannot coerce
        def coerce(_value)
          nil
        end

        # Override in subclasses to add constraint validation
        # @param value the validated value
        # @param errors [Array] error accumulator
        # @param location [Array] current location path
        # @param strict [Boolean] strict mode flag
        # @return [Object] the (potentially transformed) value
        def validate_constraints(value, _errors, _location, strict: false)
          value
        end

        # Expected type name for error messages
        # @return [String] human-readable type name
        def expected_type_name
          raise NotImplementedError, "Type validators must implement #expected_type_name"
        end

        protected

        def error(type:, loc:, msg:, input: nil)
          ErrorDetail.new(type: type, loc: loc, msg: msg, input: input)
        end

        def type_error(value, location)
          error(type: :type_error, loc: location, msg: "Expected #{expected_type_name}, got #{value.class.name}", 
                input: value)
        end
      end
    end
  end
end