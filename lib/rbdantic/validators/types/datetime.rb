# frozen_string_literal: true

require "date"
require_relative "base"

module Rbdantic
  module Validators
    module Types
      class DateTime < Base
        def matches_type?(value)
          value.is_a?(::DateTime)
        end

        def expected_type_name
          "DateTime"
        end

        def coerce(value)
          case value
          when ::DateTime
            value
          when ::Time
            value.to_datetime
          when ::Date
            value.to_datetime
          when ::String
            ::DateTime.iso8601(value)
          when ::Integer, ::Float
            # Unix timestamp in seconds since 1970-01-01 00:00:00 UTC
            # Integer: whole seconds (e.g., 86400 => 1970-01-02 00:00:00)
            # Float: preserves fractional seconds (e.g., 86400.5 => 1970-01-02 00:00:00.5)
            ::DateTime.new(1970, 1, 1) + (value / 86_400.0)
          end
        rescue ArgumentError
          nil
        end
      end
    end
  end
end