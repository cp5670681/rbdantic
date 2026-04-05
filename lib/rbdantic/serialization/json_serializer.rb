# frozen_string_literal: true

require "json"

module Rbdantic
  module Serialization
    # JSON serialization and deserialization
    class JsonSerializer
      # Serialize model to JSON string
      # @param model [BaseModel] the model instance
      # @param indent [Integer, nil] JSON indentation
      # @return [String] JSON string
      def self.dump(model, indent: nil, **options)
        data = Dumper.dump(model, mode: :json, **options)

        if indent
          JSON.pretty_generate(data, indent: normalize_indent(indent))
        else
          JSON.generate(data)
        end
      end

      # Parse JSON string into model
      # @param json_string [String] JSON data
      # @param model_class [Class] target model class
      # @return [BaseModel] model instance
      def self.load(json_string, model_class)
        data = JSON.parse(json_string, symbolize_names: true)
        model_class.new(data)
      end

      # Parse JSON string into model (raises on error)
      # @param json_string [String] JSON data
      # @param model_class [Class] target model class
      # @return [BaseModel] model instance
      def self.parse!(json_string, model_class)
        load(json_string, model_class)
      end

      # Parse JSON string safely, returns nil on error
      # @param json_string [String] JSON data
      # @param model_class [Class] target model class
      # @return [BaseModel, nil] model instance or nil
      def self.parse(json_string, model_class)
        begin
          load(json_string, model_class)
        rescue JSON::ParserError, ValidationError
          nil
        end
      end

      def self.normalize_indent(indent)
        return indent if indent.is_a?(String)

        " " * indent.to_i
      end
      private_class_method :normalize_indent
    end
  end
end
