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

  def test_tag
    assert_equal({ tag: 'crond' }, Args.parse(['-t', 'crond']))
  end

  def test_host
    assert_equal({ host: 'db' }, Args.parse(['-o', 'db']))
  end

  def test_severity
    assert_equal({ severity: 4 }, Args.parse(['-s', 'WARNING']))
  end

  def test_abbreviated_severity
    assert_equal({ severity: 4 }, Args.parse(['-s', 'WA']))
  end

  def test_lowercase_severity
    assert_equal({ severity: 4 }, Args.parse(['-s', 'warn']))
  end

  def test_invalid_severity
    assert_raises(OptionParser::InvalidArgument) do
       Args.parse(['-s', 'Z'])
    end
  end

end
