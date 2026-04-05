# frozen_string_literal: true

module Rbdantic
  module Validators
    # Decorator for field-level validators
    # Usage:
    #   field_validator :age, mode: :after do |value|
    #     raise "must be at least 18" if value < 18
    #   end
    class FieldValidator
      MODES = %i[before after plain wrap].freeze

      attr_reader :field_name, :mode, :validator_proc

      def initialize(field_name, mode: :after, &block)
        @field_name = field_name
        @mode = validate_mode!(mode)
        @validator_proc = block
      end

      # Execute the validator
      # @param value the field value
      # @param context [ValidatorContext] validation context
      # @return [Array<ErrorDetail>] errors from validation
      def call(value, context)
        errors, = apply(value, context)
        errors
      end

      # Execute the validator and optionally transform the value
      # @param value the field value
      # @param context [ValidatorContext] validation context
      # @param handler [Proc, nil] callable for inner validation (wrap mode only)
      # @return [Array] tuple of [errors, transformed_value]
      def apply(value, context, handler = nil, &handler_block)
        errors = []
        transformed_value = value

        begin
          handler ||= handler_block

          # For wrap mode, pass handler if available (Issue 4 fix)
          if @mode == :wrap && handler
            result = @validator_proc.call(value, context, handler)
          else
            result = @validator_proc.call(value, context)
          end

          # Returning false signals validation failure.
          # Any other non-nil/non-true return value is treated as a transformed value.
          if result == false
            errors << ErrorDetail.new(
              type: :validation_failed,
              loc: [@field_name],
              msg: "Custom validation failed",
              input: value
            )
          elsif !result.nil? && result != true
            transformed_value = result
          end
        rescue StandardError => e
          errors << ErrorDetail.new(
            type: :validation_failed,
            loc: [@field_name],
            msg: e.message,
            input: value
          )
        end

        [errors, transformed_value]
      end

      private

      def validate_mode!(mode)
        unless MODES.include?(mode)
          raise ArgumentError, "mode must be one of #{MODES.join(", ")}"
        end
        mode
      end
    end
  end
end
