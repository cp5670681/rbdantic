# frozen_string_literal: true

require_relative "validators/types"

module Rbdantic
  # FieldInfo: Stores field metadata and handles validation pipeline
  class FieldInfo
    UNSET = Object.new.freeze

    attr_reader :name, :type, :constraints, :default, :default_factory,
                :optional, :validators, :default_provided, :type_validator,
                :alias_name

    CONSTRAINT_KEYS = %i[
      min_length max_length gt ge lt le pattern format
      min_items max_items unique_items element_type multiple_of
      min_properties max_properties
    ].freeze

    def self.from_dsl(name, type, metadata = nil, **options)
      meta = case metadata
             when nil then {}
             when FieldInfo then { default: metadata.default, default_factory: metadata.default_factory,
                                   optional: metadata.optional, validators: metadata.validators,
                                   alias_name: metadata.alias_name, **metadata.constraints }
             when Hash then metadata
             else raise ArgumentError, "field metadata must be a Rbdantic::FieldInfo or Hash"
             end

      opts = meta.merge(options)
      type, opts = normalize_type(type, opts)
      new(name: name, type: type, **opts)
    end

    def self.normalize_type(type, options)
      return [Array, options.merge(element_type: type.first)] if type.is_a?(Array) && type.length == 1
      [type, options]
    end

    def initialize(name: nil, type: nil, default: UNSET, default_factory: nil,
                   optional: nil, required: nil, validators: nil, alias_name: nil, **constraints)
      @name = name
      @type = type
      @alias_name = alias_name
      @default = default.equal?(UNSET) ? nil : default
      @default_provided = !default.equal?(UNSET)
      @default_factory = default_factory
      @optional = required == false ? true : (optional || false)
      @validators = validators || []
      validate_constraint_keys!(constraints)
      @constraints = constraints.slice(*CONSTRAINT_KEYS).freeze

      validate_mutable_default! if @default_provided && !@default_factory
      validate_constraint_compatibility! if @type
      @type_validator = Validators::Types.create_validator(@type, **@constraints)
    end

    def has_default?; @default_provided || !@default_factory.nil?; end
    def get_default; @default_factory ? @default_factory.call : @default; end
    def required?; !@optional && !has_default?; end

    # Main validation entry point
    # @param value the value to validate
    # @param model_instance the model instance being validated
    # @param context [ValidatorContext] validation context
    # @return [Array<ErrorDetail>, value] tuple of errors and validated value
    def validate(value, model_instance, context)
      return handle_nil_value if value.nil?

      strict = model_instance.class.model_config.strict
      custom_validators = model_instance.class.field_validators[@name] || []

      errors, value = run_before_validators(value, custom_validators, context)
      return [errors, value] if errors.any?

      run_main_validation(value, custom_validators, context, strict)
    end

    private

    # Handle nil values - either allow (optional) or error (required)
    def handle_nil_value
      return [[], nil] if @optional
      [[required_error, nil]]
    end

    def required_error
      ErrorDetail.new(type: :type_error, loc: [@name], msg: "Field is required", input: nil)
    end

    # Run before validators, return errors and potentially transformed value
    def run_before_validators(value, custom_validators, context)
      apply_validators_by_mode(value, custom_validators, :before, context)
    end

    # Main validation: wrap -> plain -> core (in priority order)
    def run_main_validation(value, custom_validators, context, strict)
      base_handler = if custom_validators.any? { |validator| validator.mode == :plain }
                       ->(current_value) { apply_validators_by_mode(current_value, custom_validators, :plain, context) }
                     else
                       ->(current_value) { run_core_validation(current_value, custom_validators, context, strict) }
                     end

      wrap_validators = custom_validators.select { |validator| validator.mode == :wrap }
      return base_handler.call(value) if wrap_validators.empty?

      handler = wrap_validators.reduce(base_handler) do |next_handler, validator|
        ->(current_value) { validator.apply(current_value, context, next_handler) }
      end

      handler.call(value)
    end

    # Core validation: type -> proc -> after
    def run_core_validation(value, custom_validators, context, strict)
      errors, value = run_type_validation(value, strict)
      return [errors, value] if errors.any?

      errors = run_proc_validators(value)
      return [errors, value] if errors.any?

      apply_validators_by_mode(value, custom_validators, :after, context)
    end

    def run_type_validation(value, strict)
      return [[], value] unless @type_validator
      @type_validator.validate(value, [@name], strict: strict)
    end

    def run_proc_validators(value)
      @validators.each_with_object([]) do |v, errs|
        next unless v.is_a?(Proc) || v.is_a?(Method)
        result = v.call(value)
        errs << proc_error(value, result) if proc_failed?(result)
      end
    end

    def proc_failed?(result)
      result == false || result.is_a?(String)
    end

    def proc_error(value, result)
      msg = result.is_a?(String) ? result : "Custom validation failed"
      ErrorDetail.new(type: :validation_failed, loc: [@name], msg: msg, input: value)
    end

    def apply_validators_by_mode(value, validators, mode, context)
      errors, current = [], value
      validators.select { |v| v.mode == mode }.each do |v|
        errs, transformed = v.apply(current, context)
        errors.concat(errs)
        current = transformed if errs.empty?
      end
      [errors, current]
    end

    def validate_mutable_default!
      return unless @default.is_a?(::Array) || @default.is_a?(::Hash)
      raise ArgumentError, "Mutable default '#{@default.class.name}' detected for field '#{@name}'. " \
                           "Use `default_factory` to avoid shared state."
    end

    def validate_constraint_keys!(constraints)
      unknown = constraints.keys - CONSTRAINT_KEYS
      return if unknown.empty?

      raise ArgumentError, "Unknown constraint(s) for field '#{@name}': #{unknown.join(", ")}"
    end

    def validate_constraint_compatibility!
      if @constraints.key?(:multiple_of) && @constraints[:multiple_of].to_f.zero?
        raise ArgumentError, "multiple_of must not be 0"
      end

      return unless @constraints[:format]
      return if @type == ::String && Validators::Types::String::FORMAT_PATTERNS.key?(@constraints[:format])

      if @type == ::String
        raise ArgumentError, "Unsupported format '#{@constraints[:format]}' for field '#{@name}'"
      end

      raise ArgumentError, "format is only supported for String fields"
    end
  end

  Field = FieldInfo
  def self.Field(**options); FieldInfo.new(**options); end
end
