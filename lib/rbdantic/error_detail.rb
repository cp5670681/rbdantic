# frozen_string_literal: true

module Rbdantic
  # Pydantic-compatible error detail structure
  class ErrorDetail
    attr_reader :type, :loc, :msg, :input

    def initialize(type:, loc:, msg:, input: nil)
      @type = type
      @loc = loc
      @msg = msg
      @input = input
    end

    def to_h
      { type: @type, loc: @loc, msg: @msg, input: @input }.compact
    end

    def as_json(*)
      to_h
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end

  # Raised when model validation fails
  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(build_message)
    end

    def error_count
      @errors.length
    end

    def as_json(*)
      { errors: @errors.map(&:as_json), error_count: error_count }
    end

    alias to_h as_json

    private

    def build_message
      "#{error_count} validation error(s):\n" +
        @errors.map { |e| "  - #{e.loc.join(".")}: #{e.msg}" }.join("\n")
    end
  end
end