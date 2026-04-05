# frozen_string_literal: true

module Rbdantic
  module Validators
    # Context object passed to validators during validation
    class ValidatorContext
      attr_reader :field_name, :field_info, :model_class, :model_instance, :data

      def initialize(
        field_name: nil,
        field_info: nil,
        model_class: nil,
        model_instance: nil,
        data: {}
      )
        @field_name = field_name
        @field_info = field_info
        @model_class = model_class
        @model_instance = model_instance
        @data = data
      end

      # Create an error detail object
      def create_error(type:, msg:, input: nil)
        ErrorDetail.new(
          type: type,
          loc: [@field_name],
          msg: msg,
          input: input
        )
      end

      # Access other field values (for cross-field validation)
      def field_value(name)
        if @data.key?(name)
          @data[name]
        else
          @model_instance&.instance_variable_get("@#{name}")
        end
      end
    end
  end
end
