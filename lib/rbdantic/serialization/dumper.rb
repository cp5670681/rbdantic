# frozen_string_literal: true

module Rbdantic
  module Serialization
    # Handles model_dump with various options
    class Dumper
      def self.dump(model, **options)
        new(model, **options).dump
      end

      def initialize(model, mode: nil, include: nil, exclude: nil,
                     exclude_unset: false, exclude_defaults: false, by_alias: false)
        @model = model
        @mode = mode
        @include = include
        @exclude = exclude
        @exclude_unset = exclude_unset
        @exclude_defaults = exclude_defaults
        @by_alias = by_alias
        @set_fields = Array(model.instance_variable_get("@__fields_set__"))
      end

      def dump
        result = {}

        @model.class.fields.each do |name, field_info|
          next if should_exclude?(name, field_info)
          
          # Use alias if requested and present
          output_name = (@by_alias && field_info.alias_name) ? field_info.alias_name.to_sym : name.to_sym
          
          result[output_name] = serialize_item(
            @model.instance_variable_get("@#{name}"),
            **nested_dump_options(name, field_info)
          )
        end

        extra_fields.each do |name|
          next if should_exclude_extra?(name)
          result[name.to_sym] = serialize_item(@model.instance_variable_get("@#{name}"))
        end

        result
      end

      private

      def extra_fields
        Array(@model.instance_variable_get("@__extra_fields__"))
      end

      def should_exclude?(name, field_info)
        return true if filter_matches?(@exclude, name, field_info)
        return true if @include && !filter_matches?(@include, name, field_info)
        return true if @exclude_unset && !@set_fields.include?(name)

        if @exclude_defaults && field_info.has_default? && field_info.default_factory.nil?
          current_val = @model.instance_variable_get("@#{name}")
          return true if current_val == field_info.default
        end

        false
      end

      def should_exclude_extra?(name)
        return true if extra_filter_matches?(@exclude, name)
        return true if @include && !extra_filter_matches?(@include, name)
        return true if @exclude_unset && !@set_fields.include?(name)
        false
      end

      def nested_dump_options(field_name, field_info)
        {
          mode: @mode,
          exclude_defaults: @exclude_defaults,
          exclude_unset: @exclude_unset,
          by_alias: @by_alias,
          include: nested_filter_for(@include, field_name, field_info),
          exclude: nested_filter_for(@exclude, field_name, field_info)
        }
      end

      def nested_filter_for(filter, field_name, field_info = nil)
        return unless filter.is_a?(Hash)

        filter_keys_for(field_name, field_info).each do |key|
          return filter[key] if filter.key?(key)
        end

        nil
      end

      def serialize_item(item, **options)
        case item
        when Rbdantic::BaseModel then Dumper.dump(item, **options)
        when Array then item.map { |v| serialize_item(v, **options) }
        when Hash then item.transform_values { |v| serialize_item(v, **options) }
        else item
        end
      end

      def filter_matches?(filter, field_name, field_info)
        return false unless filter

        if filter.is_a?(Hash)
          filter_keys_for(field_name, field_info).any? { |key| filter.key?(key) }
        else
          filter_keys_for(field_name, field_info).any? { |key| filter.include?(key) }
        end
      end

      def extra_filter_matches?(filter, field_name)
        return false unless filter

        keys = filter_keys_for(field_name)
        if filter.is_a?(Hash)
          keys.any? { |key| filter.key?(key) }
        else
          keys.any? { |key| filter.include?(key) }
        end
      end

      def filter_keys_for(field_name, field_info = nil)
        keys = [field_name, field_name.to_s]
        if @by_alias && field_info&.alias_name
          keys << field_info.alias_name.to_sym
          keys << field_info.alias_name.to_s
        end
        keys.uniq
      end
    end
  end
end
