# frozen_string_literal: true

module Rbdantic
  module Validators
    module Types
      # Abstract base for numeric validators (Integer, Float)
      class Number < Base
        # Tolerance constants for floating-point comparison
        FLOAT_TOLERANCE_FACTOR = 1e-9
        MIN_FLOAT_TOLERANCE = 1e-12

        def matches_type?
          raise NotImplementedError
        end

        def expected_type_name
          raise NotImplementedError
        end

        def validate_constraints(value, errors, location, strict: false)
          validate_bounds(value, errors, location)
          validate_multiple_of(value, errors, location) if constraints[:multiple_of]
          value
        end

        private

        def validate_bounds(value, errors, location)
          if constraints[:gt] && value <= constraints[:gt]
            errors << error(type: :value_not_greater_than, loc: location, 
                            msg: "Value must be greater than #{constraints[:gt]}", input: value)
          end
          if constraints[:ge] && value < constraints[:ge]
            errors << error(type: :value_not_greater_than_or_equal, loc: location, 
                            msg: "Value must be greater than or equal to #{constraints[:ge]}", input: value)
          end
          if constraints[:lt] && value >= constraints[:lt]
            errors << error(type: :value_not_less_than, loc: location, 
                            msg: "Value must be less than #{constraints[:lt]}", input: value)
          end
          if constraints[:le] && value > constraints[:le]
            errors << error(type: :value_not_less_than_or_equal, loc: location, 
                            msg: "Value must be less than or equal to #{constraints[:le]}", input: value)
          end
        end

        def validate_multiple_of(value, errors, location)
          multiple = constraints[:multiple_of].abs
          remainder = value % multiple
          tolerance = numeric_type? ? [multiple * FLOAT_TOLERANCE_FACTOR, MIN_FLOAT_TOLERANCE].max : 0
          if remainder > tolerance && remainder < multiple - tolerance
            errors << error(type: :value_not_multiple_of, loc: location, 
                            msg: "Value must be a multiple of #{constraints[:multiple_of]}", input: value)
          end
        end

        def numeric_type?
          false
        end
      end
    end
  end
end