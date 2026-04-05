# frozen_string_literal: true

require_relative "defs_registry"

module Rbdantic
  module JsonSchema
    # Generate JSON Schema from model class
    class Generator
      # JSON Schema version
      SCHEMA_VERSION = "https://json-schema.org/draft/2020-12/schema"

      # Generate schema for a model class
      # @param model_class [Class] the model class
      # @param options [Hash] generation options
      # @option options [String] :title optional title (defaults to class name)
      # @option options [String] :description optional description
      # @option options [String] :schema_id optional $id for the schema
      # @option options [Boolean] :include_defaults include default values in schema
      # @option options [DefsRegistry] :defs_registry registry for $defs/$ref pattern
      # @return [Hash] JSON Schema
      def self.generate(model_class, **options)
        new(model_class, **options).generate
      end

      def initialize(model_class, title: nil, description: nil, schema_id: nil,
                     include_defaults: true, top_level: true, defs_registry: nil, by_alias: false)
        @model_class = model_class
        @title = title || model_class.name
        @description = description
        @schema_id = schema_id
        @include_defaults = include_defaults
        @top_level = top_level
        @by_alias = by_alias
        # Use provided registry or create one at top level
        @defs_registry = defs_registry || (top_level ? DefsRegistry.new : nil)
      end

      def generate
        # Handle circular references - if being processed, return $ref
        if @defs_registry && @defs_registry.being_processed?(@model_class)
          return @defs_registry.ref_for(@model_class)
        end

        schema = {}

        # Only add $schema and $id at top level
        if @top_level
          schema["$schema"] = SCHEMA_VERSION
          schema["$id"] = @schema_id if @schema_id
        end

        schema["type"] = "object"

        # Add optional metadata
        schema["title"] = @title if @title && @top_level
        schema["description"] = @description if @description

        # Mark as being processed before processing fields (for cycle detection)
        if @defs_registry
          @defs_registry.mark_processing(@model_class)
        end

        # Generate properties
        properties = {}
        required = []

        @model_class.fields.each do |name, field_info|
          property_name = schema_property_name(name, field_info)
          properties[property_name] = generate_property(field_info)
          required << property_name if field_info.required?
        end

        schema["properties"] = properties
        schema["required"] = required if required.any?

        # Create a copy of schema for $defs (without $defs key to avoid circular JSON)
        defs_schema = {
          "type" => "object",
          "title" => @title,
          "description" => @description,
          "properties" => properties
        }.compact
        defs_schema["required"] = required if required.any?

        # Register this model's schema in defs registry
        if @defs_registry
          @defs_registry.register(@model_class, defs_schema)
        end

        # Add $defs at top level if we have referenced models
        if @top_level && @defs_registry
          defs = if @defs_registry.referenced?(@model_class)
                   @defs_registry.defs_hash
                 else
                   @defs_registry.defs_hash(except: @model_class)
                 end
          if defs && defs.any?
            schema["$defs"] = defs
          end
        end

        schema
      end

      private

      def generate_property(field_info)
        schema = Types.to_schema(
          field_info.type,
          **field_info.constraints,
          defs_registry: @defs_registry,
          by_alias: @by_alias
        )

        # Handle optional fields - allow null
        schema = handle_optional(schema) if field_info.optional

        # Include default value if present and not a factory
        if @include_defaults && field_info.has_default? && !field_info.default_factory
          schema["default"] = field_info.default
        end

        schema
      end

      def handle_optional(schema)
        if schema["$ref"]
          # For $ref, use oneOf to allow null
          { "oneOf" => [schema, { "type" => "null" }] }
        elsif schema["type"].is_a?(Array)
          schema["type"] = schema["type"] + ["null"]
          schema
        else
          schema["type"] = [schema["type"], "null"]
          schema
        end
      end

      def schema_property_name(name, field_info)
        if @by_alias && field_info.alias_name
          field_info.alias_name.to_s
        else
          name.to_s
        end
      end
    end
  end
end
