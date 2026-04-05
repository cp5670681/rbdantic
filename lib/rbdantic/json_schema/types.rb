# frozen_string_literal: true

module Rbdantic
  module JsonSchema
    # Type-to-schema mappings
    module Types
      # Map Ruby type to JSON Schema type
      # @param type [Class] Ruby type
      # @param constraints [Hash] field constraints
      # @param defs_registry [DefsRegistry] registry for $defs/$ref pattern
      # @return [Hash] JSON Schema for the type
      def self.to_schema(type, **constraints)
        defs_registry = constraints[:defs_registry]
        by_alias = constraints[:by_alias]
        constraints = constraints.reject { |k, _| k == :defs_registry || k == :by_alias }

        schema = base_schema(type, defs_registry: defs_registry, by_alias: by_alias)

        # Add constraints
        add_string_constraints(schema, constraints) if type == ::String
        add_numeric_constraints(schema, constraints) if type == ::Integer || type == ::Float
        add_array_constraints(schema, constraints, defs_registry: defs_registry, by_alias: by_alias) if type == ::Array
        add_hash_constraints(schema, constraints) if type == ::Hash

        schema
      end

      def self.base_schema(type, defs_registry: nil, by_alias: false)
        # Use direct class comparison (type == Class), not === (which checks instance type)
        if type == ::String
          { "type" => "string" }
        elsif type == ::Integer
          { "type" => "integer" }
        elsif type == ::Float
          { "type" => "number" }
        elsif type == ::Time
          { "type" => "string", "format" => "date-time" }
        elsif type == ::Rbdantic::Boolean
          { "type" => "boolean" }
        elsif type == ::Array
          { "type" => "array" }
        elsif type == ::Hash
          { "type" => "object" }
        elsif type.is_a?(Class) && type < ::Rbdantic::BaseModel
          if defs_registry
            unless defs_registry.registered?(type) || defs_registry.being_processed?(type)
              Generator.generate(type, top_level: false, defs_registry: defs_registry, by_alias: by_alias)
            end

            defs_registry.ref_for(type)
          else
            Generator.generate(type, top_level: false, defs_registry: nil, by_alias: by_alias)
          end
        else
          { "type" => "object" }
        end
      end

      def self.add_string_constraints(schema, constraints)
        schema["minLength"] = constraints[:min_length] if constraints[:min_length]
        schema["maxLength"] = constraints[:max_length] if constraints[:max_length]
        schema["pattern"] = constraints[:pattern].source if constraints[:pattern]

        if constraints[:format]
          format_map = {
            email: "email",
            uri: "uri",
            uuid: "uuid"
          }
          schema["format"] = format_map[constraints[:format]] if format_map[constraints[:format]]
        end
      end

      def self.add_numeric_constraints(schema, constraints)
        schema["minimum"] = constraints[:ge] if constraints[:ge]
        schema["exclusiveMinimum"] = constraints[:gt] if constraints[:gt]
        schema["maximum"] = constraints[:le] if constraints[:le]
        schema["exclusiveMaximum"] = constraints[:lt] if constraints[:lt]
        schema["multipleOf"] = constraints[:multiple_of] if constraints[:multiple_of]
      end

      def self.add_array_constraints(schema, constraints, defs_registry: nil, by_alias: false)
        schema["minItems"] = constraints[:min_items] if constraints[:min_items]
        schema["maxItems"] = constraints[:max_items] if constraints[:max_items]
        schema["uniqueItems"] = constraints[:unique_items] if constraints[:unique_items]
        if constraints[:element_type]
          schema["items"] =
            to_schema(constraints[:element_type], defs_registry: defs_registry, by_alias: by_alias)
        end
      end

      def self.add_hash_constraints(schema, constraints)
        schema["minProperties"] = constraints[:min_properties] if constraints[:min_properties]
        schema["maxProperties"] = constraints[:max_properties] if constraints[:max_properties]
      end
    end
  end
end
