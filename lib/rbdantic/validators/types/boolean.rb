# frozen_string_literal: true

require_relative "base"

module Rbdantic
  module Validators
    module Types
      class Boolean < Base
        def matches_type?(value)
          value.is_a?(TrueClass) || value.is_a?(FalseClass)
        end

        def expected_type_name
          "Boolean"
        end

        def coerce(value)
          return value if value == true || value == false

          case value
          when ::String
            str = value.strip.downcase
            return true if str == "true" || str == "1" || str == "yes" || str == "on"
            return false if str == "false" || str == "0" || str == "no" || str == "off"
            nil
          when ::Integer
            return true if value == 1
            return false if value == 0
            nil
          else
            nil
          end
        end
      end
    end
  end
end
