require 'minitest/autorun'
require 'rbdantic'
require 'date'


class RbdanticTest < Minitest::Test
  class M1 < Rbdantic::BaseModel
    field :id, Integer
    field :time, DateTime
    field :list, Array do
      field :abc, Integer
    end
  end

  def test_1
    # m = M1(id=1, time="2022-08-01 01:00:00", list=[{abc: 2}])
  end
end