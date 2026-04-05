# frozen_string_literal: true

require_relative "base"

module Rbdantic
  module Validators
    module Types
      # Validator for nested model types
      class Model < Base
        attr_reader :model_class

        def initialize(model_class, **constraints)
          super(**constraints)
          @model_class = model_class
        end

        def matches_type?(value)
          value.is_a?(@model_class)
        end

        def expected_type_name
          @model_class.name
        end

        # Model validation has special handling for nil and Hash
        # so we override validate entirely
        def validate(value, location = [], strict: false)
          return [[], nil] if value.nil?

          if matches_type?(value)
            return [validate_existing_instance(value, location, strict: strict), value]
          end

          if value.is_a?(::Hash)
            if strict
              return [
                [error(type: :type_error, loc: location, msg: "Expected #{expected_type_name}, got Hash", input: value)],
                value
              ]
            end
            begin
              return [[], @model_class.new(value)]
            rescue ValidationError => e
              return [remap_errors(e.errors, location), value]
            end
          end

          [
            [error(type: :type_error, loc: location, msg: "Expected #{expected_type_name}, got #{value.class.name}", input: value)],
            value
          ]
        end

        def validate_constraints(value, _errors, _location, strict: false)
          value
        end

        private

        def validate_existing_instance(model, location, strict: false)
          model.class.new(model.model_dump)
          []
        rescue ValidationError => e
          remap_errors(e.errors, location)
        end

        def remap_errors(errors, location)
          errors.map do |err|
            ErrorDetail.new(type: err.type, loc: location + err.loc, msg: err.msg, input: err.input)
          end
        end
      end
    end
  end
end
