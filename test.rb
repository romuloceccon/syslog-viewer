require 'test/unit'
require 'syslog-viewer'

class ArgsTestCase < Test::Unit::TestCase

  def test_count
    assert_equal({ count: 100 }, Args.parse(['-n', '100']))
  end

  def test_follow
    assert_equal({ follow: true }, Args.parse(['-f']))
  end

  def test_first_line
    assert_equal({ first_line: true }, Args.parse(['-1']))
  end

end
