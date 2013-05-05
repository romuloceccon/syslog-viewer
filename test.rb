require 'test/unit'
require 'syslog-viewer'

class ArgsTestCase < Test::Unit::TestCase

  def test_count
    assert_equal({ count: 100 }, Args.parse(['-n', '100']))
  end

end
