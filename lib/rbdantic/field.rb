module Rbdantic
  class Field
    attr_accessor :default, :type, :default_factory, :title, :description, :gt, :lt, :min_length, :max_length
    def initialize(
      default = nil, 
      type = nil,
      default_factory: nil,
      title: nil,
      description: nil,
      gt: nil,
      lt: nil,
      min_length: nil,
      max_length: nil
    )
      self.default = default
      self.type = type
      self.default_factory = default_factory
      self.title = title
      self.description = description
      self.gt = gt
      self.lt = lt
      self.min_length = min_length
      self.max_length = max_length
    end
  end

  class IntegerField < Field
  end

  class ArrayField < Field
    attr_accessor :children
    def initialize(*args, **kwargs)
      self.children = []
      super(*args, **kwargs)
    end
  end
end
