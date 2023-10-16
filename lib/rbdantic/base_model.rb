require 'date'

module Rbdantic
  class BaseModel
    attr_accessor :attrs
    class << self
      attr_accessor :fields

      def field(name, type, default: nil, description: nil, &block)
        self.fields ||= {}
        self.fields[name] = Rbdantic::Field.new(type = type, default = default, description: description)
        if block_given?
          child_model = Class.new(BaseModel)
          child_model.instance_eval(&block)
          self.fields[name] = child_model
        end
      end
    end

    def initialize(**kwargs)
      self.attrs = {}
      kwargs.each do |k, v|
        if self.class.fields.keys.include?(k)
          field = self.class.fields[k]
          if field.type == Integer
            self.attrs[k] = Integer(v)
          elsif field.type == DateTime
            if v.is_a? String
              self.attrs[k] = DateTime.parse(v)
            else
              self.attrs[k] = v
            end
          else
            self.attrs[k] = v
          end
          define_singleton_method k do 
            self.attrs[k]
          end
        else
          raise NoMethodError("#{k}方法未定义")
        end
      end
    end
  end
end
  