# frozen_string_literal: true

require "set"

module Rbdantic
  module JsonSchema
    # Registry for tracking model schemas during generation
    # Used to implement $defs/$ref pattern for circular references
    class DefsRegistry
      def initialize
        @defs = {}
        @being_processed = Set.new  # Currently being processed (for cycle detection)
        @referenced = Set.new
      end

      def key_for(model_class)
        model_class.name || "AnonymousModel_#{model_class.object_id}"
      end

      # Check if a model is currently being processed (for cycle detection)
      # @param model_class [Class] the model class
      # @return [Boolean]
      def being_processed?(model_class)
        @being_processed.include?(model_class)
      end

      # Mark a model as being processed
      # @param model_class [Class] the model class
      def mark_processing(model_class)
        @being_processed.add(model_class)
      end

      # Register a model's completed schema and return its key
      # @param model_class [Class] the model class
      # @param schema [Hash] the generated schema
      # @return [String] the key used in $defs
      def register(model_class, schema)
        key = key_for(model_class)
        @defs[key] = schema
        @being_processed.delete(model_class)  # No longer being processed
        key
      end

      # Check if a model's schema is registered (completed)
      # @param model_class [Class] the model class
      # @return [Boolean]
      def registered?(model_class)
        @defs.key?(key_for(model_class))
      end

      def referenced?(model_class)
        @referenced.include?(key_for(model_class))
      end

      # Generate a $ref for a registered model
      # @param model_class [Class] the model class
      # @return [Hash] the $ref object
      def ref_for(model_class)
        key = key_for(model_class)
        @referenced.add(key)
        { "$ref" => "#/$defs/#{key}" }
      end

      # Get the $defs hash for inclusion in top-level schema
      # @return [Hash, nil] the defs hash or nil if empty
      def defs_hash(except: nil)
        defs = except ? @defs.reject { |key, _| key == key_for(except) } : @defs
        defs.empty? ? nil : defs
      end

      # Clear the registry (for fresh generation)
      def clear
        @defs.clear
        @being_processed.clear
        @referenced.clear
      end
    end
  end
end
