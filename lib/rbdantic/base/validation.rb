# frozen_string_literal: true

module Rbdantic
  class BaseModel
    module Validation
      def initialize(data = {})
        data = normalize_attributes(data)
        errors, processed, provided, extra, consumed = [], {}, [], [], []

        # 1. Before model validators (Status Safe)
        data = run_before_model_validators(data, errors)

        # 2. Process Fields
        validate_fields(data, processed, errors, provided, consumed)

        # 3. Extra Fields
        handle_extra_fields(data, processed, extra, errors, consumed)

        raise ValidationError.new(errors) if errors.any?

        # 4. Success - Set state
        finalize_state(processed, provided, extra)

        # 5. After model validators
        run_after_model_validators(errors)
        raise ValidationError.new(errors) if errors.any?
        freeze if self.class.model_config.frozen
      end

      private

      def run_before_model_validators(data, errors)
        current_data = data.dup
        self.class.model_validators.select { |v| v.mode == :before }.each do |v|
          begin
            result = v.call(current_data)
            raise TypeError, "Before model validators must return a Hash" unless result.is_a?(Hash)
            current_data = normalize_attributes(result)
          rescue StandardError => e
            errors << ErrorDetail.new(type: :model_validation_failed, loc: [], msg: e.message, input: current_data)
          end
        end
        current_data
      end

      def validate_fields(data, processed, errors, provided, consumed)
        self.class.fields.each do |name, field|
          present, input_key, input_value = resolve_input(data, name, field)

          if present
            provided << name
            consumed << input_key
            field_errors, value = field.validate(input_value, self, build_validator_context(name, field, processed))
            errors.concat(field_errors)
            processed[name] = value
          elsif field.has_default?
            processed[name] = field.get_default
          elsif field.required?
            errors << ErrorDetail.new(type: :value_missing, loc: [name], msg: "Field '#{name}' is required", input: nil)
          end
        end
      end

      def handle_extra_fields(data, processed, extra_fields, errors, consumed)
        (data.keys - consumed).each do |name|
          case self.class.model_config.extra
          when :forbid
            errors << ErrorDetail.new(type: :extra_field_forbidden, loc: [name], 
                                      msg: "Extra field '#{name}' is not allowed", input: data[name])
          when :allow
            extra_fields << name
            processed[name] = data[name]
          end
        end
      end

      def finalize_state(processed, provided, extra)
        processed.each { |name, value| instance_variable_set("@#{name}", value) }
        @__fields_set__ = (provided + extra).uniq
        @__extra_fields__ = extra.uniq
      end

      def run_after_model_validators(errors)
        self.class.model_validators.select { |v| v.mode == :after }.each do |v|
          errors.concat(v.validate(self))
        end
      end

      def normalize_attributes(data)
        raise ArgumentError, "BaseModel expects a Hash" unless data.is_a?(Hash)
        data.transform_keys { |k| (k.is_a?(String) || k.is_a?(Symbol)) ? k.to_sym : k }
      end

      def resolve_input(data, name, field)
        return [true, name, data[name]] if data.key?(name)

        alias_name = field.alias_name&.to_sym
        return [false, nil, nil] unless alias_name && data.key?(alias_name)

        [true, alias_name, data[alias_name]]
      end

      def build_validator_context(name, field_info, data = {})
        Validators::ValidatorContext.new(field_name: name, field_info: field_info, model_class: self.class, 
                                         model_instance: self, data: data)
      end

      def assign_field(name, value)
        field = self.class.fields[name]
        unless self.class.model_config.validate_assignment
          return (instance_variable_set("@#{name}", value);
                  track_set_field(name); value)
        end

        errors, processed = field.validate(value, self, build_validator_context(name, field, current_field_data))
        raise ValidationError.new(errors) if errors.any?
        
        previous = instance_variable_get("@#{name}")
        instance_variable_set("@#{name}", processed)
        
        begin
          model_errors = []
          run_after_model_validators(model_errors)
          raise ValidationError.new(model_errors) if model_errors.any?
        rescue StandardError
          instance_variable_set("@#{name}", previous)
          raise
        end
        track_set_field(name)
        processed
      end

      def assign_extra_field(name, value)
        case self.class.model_config.extra
        when :forbid then raise ValidationError.new([ErrorDetail.new(type: :extra_field_forbidden, loc: [name], 
                                                                     msg: "Extra field '#{name}' is not allowed", input: value)])
        when :allow then (instance_variable_set("@#{name}", value);
                          track_set_field(name); track_extra_field(name); value)
        end
      end

      def current_field_data
        self.class.fields.keys.each_with_object({}) do |name, acc|
          acc[name] = instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")
        end
      end

      def track_set_field(name); (@__fields_set__ ||= []) << name unless @__fields_set__&.include?(name); end
      def track_extra_field(name); (@__extra_fields__ ||= []) << name unless @__extra_fields__&.include?(name); end
    end
  end
end
