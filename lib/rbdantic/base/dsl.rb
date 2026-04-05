# frozen_string_literal: true

module Rbdantic
  class BaseModel
    module DSL
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def model_fields; @__rbdantic_fields__ ||= {}; end
        alias fields model_fields

        def field_validators; @__rbdantic_field_validators__ ||= {}; end
        def model_validators; @__rbdantic_model_validators__ ||= []; end

        def field(name, type, metadata = nil, **options)
          field_info = FieldInfo.from_dsl(name, type, metadata, **options)
          (@__rbdantic_fields__ ||= {})[name] = field_info

          define_method(name) { instance_variable_get("@#{name}") }
          define_method("#{name}=") do |value|
            raise FrozenError, "cannot modify frozen #{self.class.name}" if self.class.model_config.frozen
            assign_field(name, value)
          end
        end

        def model_config(**options)
          @__rbdantic_model_config__ ||= ModelConfig.new
          options.empty? ? @__rbdantic_model_config__ : @__rbdantic_model_config__ = @__rbdantic_model_config__.with(**options)
        end

        def inherited(subclass)
          subclass.instance_variable_set(:@__rbdantic_fields__, fields.dup)
          subclass.instance_variable_set(:@__rbdantic_model_config__, model_config.dup)
          subclass.instance_variable_set(:@__rbdantic_field_validators__, field_validators.each_with_object({}) do |(k, v), h|
            h[k] = v.dup
          end)
          subclass.instance_variable_set(:@__rbdantic_model_validators__, model_validators.dup)
          super
        end

        def field_validator(field_name, mode: :after, &block)
          ((@__rbdantic_field_validators__ ||= {})[field_name] ||= []) << Validators::FieldValidator.new(field_name, 
                                                                                                         mode: mode, &block)
        end

        def model_validator(mode: :after, &block)
          (@__rbdantic_model_validators__ ||= []) << Validators::ModelValidator.new(mode: mode, &block)
        end

        # Rebuild model fields (useful after inheritance or dynamic changes)
        # Re-creates field accessors and validators
        def model_rebuild
          fields.each do |name, _|
            define_method(name) { instance_variable_get("@#{name}") }
            define_method("#{name}=") do |value|
              raise FrozenError, "cannot modify frozen #{self.class.name}" if self.class.model_config.frozen
              assign_field(name, value)
            end
          end
          true
        end

        def model_json_schema(**options); JsonSchema::Generator.generate(self, **options); end
        def model_validate(data); new(data); end

        def __build_instance__(attributes, fields_set:, extra_fields:)
          instance = allocate
          attributes.each { |name, value| instance.instance_variable_set("@#{name}", value) }
          instance.instance_variable_set(:@__fields_set__, fields_set.map(&:to_sym).uniq)
          instance.instance_variable_set(:@__extra_fields__, extra_fields.map(&:to_sym).uniq)
          instance.freeze if model_config.frozen
          instance
        end
      end
    end
  end
end
