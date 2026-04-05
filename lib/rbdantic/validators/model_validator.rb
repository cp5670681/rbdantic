# frozen_string_literal: true

module Rbdantic
  module Validators
    # Decorator for model-level validators
    # Usage:
    #   model_validator mode: :before do |data|
    #     data[:email] = data[:email]&.downcase
    #     data
    #   end
    class ModelValidator
      MODES = %i[before after].freeze

      attr_reader :mode, :validator_proc

      def initialize(mode: :after, &block)
        @mode = validate_mode!(mode)
        @validator_proc = block
      end

      # Execute the :before validator, which receives and must return a Hash.
      # Only valid to call when mode == :before.
      # @param data [Hash] the input data
      # @return [Hash] modified data
      def call(data)
        @validator_proc.call(data)
      end

      # Run validation and collect errors
      # @param model_instance the model instance (for after mode)
      # @return [Array<ErrorDetail>] errors from validation
      def validate(model_instance)
        errors = []

        begin
          @validator_proc.call(model_instance)
        rescue StandardError => e
          errors << ErrorDetail.new(
            type: :model_validation_failed,
            loc: [],
            msg: e.message,
            input: nil
          )
        end

        errors
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