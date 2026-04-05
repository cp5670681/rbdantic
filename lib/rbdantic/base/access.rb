# frozen_string_literal: true

require "set"

module Rbdantic
  class BaseModel
    # Accessor and serialization methods
    module Access
      def model_dump(**options)
        Serialization::Dumper.dump(self, **options)
      end

      alias to_h model_dump

      def model_dump_json(indent: nil, **options)
        Serialization::JsonSerializer.dump(self, indent: indent, **options)
      end

      def model_fields_set
        Set.new(Array(@__fields_set__))
      end

      def model_extra
        Array(@__extra_fields__).each_with_object({}) { |name, h| h[name] = instance_variable_get("@#{name}") }
      end

      def [](name)
        instance_variable_get("@#{name}")
      end

      def []=(name, value)
        raise FrozenError, "cannot modify frozen #{self.class.name}" if self.class.model_config.frozen
        self.class.fields.key?(name) ? assign_field(name, value) : assign_extra_field(name, value)
      end

      # Create a copy of the model
      # @param deep [Boolean] if true, perform deep copy of nested models and collections
      # @return [BaseModel] a new instance with copied values
      def copy(deep: false)
        attributes = deep ? deep_copy_value(model_dump) : model_dump
        rebuild_instance(attributes, fields_set: Array(@__fields_set__), extra_fields: Array(@__extra_fields__))
      end

      # Create a new model with updated fields
      # @param data [Hash] fields to update
      # @return [BaseModel] a new instance with updated values
      def update(**data)
        candidate = self.class.new(model_dump.merge(data))
        extra_fields = candidate.model_extra.keys
        declared_fields = (model_fields_set - Set.new(model_extra.keys)) | Set.new(normalized_update_field_names(data))
        fields_set = declared_fields | Set.new(extra_fields)

        rebuild_instance(candidate.model_dump, fields_set: fields_set.to_a, extra_fields: extra_fields)
      end

      def ==(other)
        other.is_a?(self.class) && model_dump == other.model_dump
      end

      alias eql? ==

      def hash
        model_dump.hash
      end

      def method_missing(name, *args, &block)
        return model_extra[name] if args.empty? && block.nil? && model_extra.key?(name)
        super
      end

      def respond_to_missing?(name, include_private = false)
        model_extra.key?(name) || super
      end

      private

      def deep_copy_value(value)
        case value
        when BaseModel
          value.copy(deep: true)
        when Hash
          value.transform_values { |v| deep_copy_value(v) }
        when Array
          value.map { |v| deep_copy_value(v) }
        else
          # Primitive types are immutable, no need to copy
          value
        end
      end

      def rebuild_instance(attributes, fields_set:, extra_fields:)
        self.class.__build_instance__(attributes, fields_set: fields_set, extra_fields: extra_fields)
      end

      def normalized_update_field_names(data)
        alias_map = self.class.fields.each_with_object({}) do |(field_name, field_info), mapping|
          mapping[field_info.alias_name.to_sym] = field_name if field_info.alias_name
        end

        data.keys.filter_map do |key|
          key = key.to_sym
          self.class.fields.key?(key) ? key : alias_map[key]
        end
      end
    end
  end
end
