# frozen_string_literal: true

module Rbdantic
  # Model configuration options
  class ModelConfig
    VALID_EXTRA_VALUES = %i[forbid ignore allow].freeze
    VALID_COERCE_MODES = %i[strict coerce].freeze

    attr_reader :strict, :extra, :frozen, :validate_assignment, :coerce_mode

    def initialize(strict: false, extra: :ignore, frozen: false, validate_assignment: true, coerce_mode: nil)
      @coerce_mode = validate_coerce_mode!(coerce_mode || (strict ? :strict : :coerce))
      strict = (@coerce_mode == :strict)
      @strict = strict
      @extra = validate_extra!(extra)
      @frozen = frozen
      @validate_assignment = validate_assignment
    end

    def to_h
      {
        strict: @strict,
        extra: @extra,
        frozen: @frozen,
        validate_assignment: @validate_assignment,
        coerce_mode: @coerce_mode
      }
    end

    def with(**overrides)
      merged = to_h.merge(overrides)

      if overrides.key?(:strict) && !overrides.key?(:coerce_mode)
        merged[:coerce_mode] = overrides[:strict] ? :strict : :coerce
      elsif overrides.key?(:coerce_mode) && !overrides.key?(:strict)
        merged[:strict] = overrides[:coerce_mode] == :strict
      end

      self.class.new(**merged)
    end

    alias merge with

    private

    def validate_extra!(value)
      unless VALID_EXTRA_VALUES.include?(value)
        raise ArgumentError, "extra must be one of #{VALID_EXTRA_VALUES.join(", ")}"
      end
      value
    end

    def validate_coerce_mode!(value)
      unless VALID_COERCE_MODES.include?(value)
        raise ArgumentError, "coerce_mode must be one of #{VALID_COERCE_MODES.join(", ")}"
      end
      value
    end
  end
end
