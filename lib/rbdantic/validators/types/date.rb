# frozen_string_literal: true

require "date"
require_relative "base"

module Rbdantic
  module Validators
    module Types
      class Date < Base
        def matches_type?(value)
          value.is_a?(::Date) && !value.is_a?(::DateTime)
        end

        def expected_type_name
          "Date"
        end

        def coerce(value)
          case value
          when ::Date
            # DateTime is a subclass of Date, so this handles both
            # But we need to convert DateTime to Date (drop time info)
            if value.is_a?(::DateTime)
              value.to_date
            else
              value
            end
          when ::Time
            value.to_date
          when ::String
            ::Date.iso8601(value)
          when ::Integer, ::Float
            # Treat as days since Unix epoch (1970-01-01)
            # Integer: whole days (e.g., 0 => 1970-01-01, 1 => 1970-01-02)
            # Float: truncated to whole days (e.g., 1.5 => 1970-01-02)
            ::Date.new(1970, 1, 1) + value
          end
        rescue ArgumentError
          nil
        end
      end
    end
  end
end