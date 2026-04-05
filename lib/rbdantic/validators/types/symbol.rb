# frozen_string_literal: true

require_relative "base"

module Rbdantic
  module Validators
    module Types
      class Symbol < Base
        MAX_SYMBOL_LENGTH = 256

        def matches_type?(value)
          value.is_a?(::Symbol)
        end

        def expected_type_name
          "Symbol"
        end

        def coerce(value)
          case value
          when ::Symbol then value
          when ::String
            value.to_sym if !value.empty? && value.length <= MAX_SYMBOL_LENGTH
          else nil
          end
        end
      end
    end
  end
end