# frozen_string_literal: true

require_relative "number"

module Rbdantic
  module Validators
    module Types
      class Float < Number
        def matches_type?(value)
          value.is_a?(::Float)
        end

        def expected_type_name
          "Float"
        end

        def numeric_type?
          true
        end

        def coerce(value)
          case value
          when ::Float then value
          when ::Integer then value.to_f
          when ::String then Float(value) rescue nil
          else nil
          end
        end
      end
    end
  end
end