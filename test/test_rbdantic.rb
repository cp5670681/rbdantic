require "minitest/autorun"
require "rbdantic"

class RbdanticTest < Minitest::Test
  class M1 < Rbdantic::BaseModel
    field :id, Rbdantic::Field.new
  end

  def test_1
    m = M1.new
  end
end