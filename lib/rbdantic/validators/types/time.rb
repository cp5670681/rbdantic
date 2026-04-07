# frozen_string_literal: true

require "time"
require_relative "base"

module Rbdantic
  module Validators
    module Types
      class Time < Base
        def matches_type?(value)
          value.is_a?(::Time)
        end

        def expected_type_name
          "Time"
        end

        def coerce(value)
          case value
          when ::Time
            value
          when ::DateTime
            value.to_time
          when ::Date
            value.to_time
          when ::String
            ::Time.iso8601(value)
          when ::Integer, ::Float
            ::Time.at(value)
          end
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
