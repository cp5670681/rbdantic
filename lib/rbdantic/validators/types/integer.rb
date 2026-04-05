# frozen_string_literal: true

require_relative "number"

module Rbdantic
  module Validators
    module Types
      class Integer < Number
        def matches_type?(value)
          value.is_a?(::Integer)
        end

        def expected_type_name
          "Integer"
        end

        def coerce(value)
          case value
          when ::Integer then value
          when ::Float then value.to_i if value == value.floor
          when ::String then Integer(value) rescue nil
          else nil
          end
        end
      end
    end
  end
end