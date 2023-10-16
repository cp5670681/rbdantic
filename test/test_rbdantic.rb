require "minitest/autorun"
require "rbdantic"

class RbdanticTest < Minitest::Test
  def test_hello
    assert_equal "hello world", Rbdantic.hi
  end
end