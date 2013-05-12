require 'test/unit'
require 'syslog-viewer'

class ArgsTestCase < Test::Unit::TestCase

  def test_should_parse_count
    assert_equal({ 'count' => 100 }, Args.parse(['-n', '100']))
  end

  def test_should_parse_follow
    assert_equal({ 'follow' => true }, Args.parse(['-f']))
  end

  def test_should_parse_first_line
    assert_equal({ 'first_line' => true }, Args.parse(['-1']))
  end

  def test_should_parse_tag
    assert_equal({ 'tag' => 'crond' }, Args.parse(['-t', 'crond']))
  end

  def test_should_parse_host
    assert_equal({ 'host' => 'db' }, Args.parse(['-o', 'db']))
  end

  def test_should_parse_severity
    assert_equal({ 'severity' => 4 }, Args.parse(['-s', 'WARNING']))
  end

  def test_should_parse_abbreviated_severity
    assert_equal({ 'severity' => 4 }, Args.parse(['-s', 'WA']))
  end

  def test_should_parse_lowercase_severity
    assert_equal({ 'severity' => 4 }, Args.parse(['-s', 'warn']))
  end

  def test_should_fail_on_invalid_severity
    assert_raises(OptionParser::InvalidArgument) do
       Args.parse(['-s', 'Z'])
    end
  end

  def test_should_parse_date_interval
    assert_equal(
        { 'period' => {
            conditions: "DeviceReportedTime >= '2013-05-05 22:20:00' AND " \
                        "DeviceReportedTime <= '2013-05-05 22:30:00'",
            order: "DeviceReportedTime", reversed: false } },
        Args.parse(['-p', '2013-05-05 22:20:00 +0000,2013-05-05 22:30:00 +0000']))
  end

  def test_should_parse_date_with_positive_count
    assert_equal(
        { 'period' => {
            conditions: "DeviceReportedTime >= '2013-05-05 22:20:00'",
            limit: 10, order: "DeviceReportedTime", reversed: false } },
        Args.parse(['-p', '2013-05-05 22:20:00 +0000,10']))
  end

  def test_should_parse_date_with_negative_count
    assert_equal(
        { 'period' => {
            conditions: "DeviceReportedTime <= '2013-05-05 22:20:00'",
            limit: 10, order: "DeviceReportedTime DESC", reversed: true } },
        Args.parse(['-p', '2013-05-05 22:20:00 +0000,-10']))
  end

  def test_should_convert_date_to_utc
    assert_equal(
        { 'period' => {
            conditions: "DeviceReportedTime >= '2013-05-05 22:20:00'",
            limit: 10, order: "DeviceReportedTime", reversed: false } },
        Args.parse(['-p', '2013-05-05 19:20:00 -0300,10']))
  end

  def test_should_assume_date_without_offset_to_be_localtime
    t_loc = Time.now
    t_utc = (t_loc + 0).utc
    fmt = '%Y-%m-%d %H:%M:%S'
    assert_equal(
        { 'period' => {
            conditions: "DeviceReportedTime >= '%s'" % t_utc.strftime(fmt),
            limit: 10, order: "DeviceReportedTime", reversed: false } },
        Args.parse(['-p', '%s,10' % t_loc.strftime(fmt)]))
  end

  def test_should_not_allow_conjunction_of_follow_and_period
    assert_raises(OptionParser::InvalidOption) do
      Args.parse(['-p', '2013-05-05 19:20:00,10', '-f'])
    end
  end

  def test_should_not_allow_conjunction_of_count_and_period
    assert_raises(OptionParser::InvalidOption) do
      Args.parse(['-p', '2013-05-05 19:20:00,10', '-n', '1'])
    end
  end

  def test_should_merge_arguments_with_conf_file
    assert_equal(
        { 'count' => 100, 'follow' => true },
        Args.parse(['-f', 'test'], <<-EOS))
test:
  count: 100
EOS
  end

  def test_should_fail_if_conf_entry_not_found
    assert_raises(OptionParser::InvalidArgument) do
      Args.parse(['test1'], <<-EOS)
test:
  follow: true
EOS
    end
  end

  def test_should_parse_period_inside_conf_file
     assert_equal(
        { 'period' => {
            conditions: "DeviceReportedTime >= '2013-05-05 22:20:00'",
            limit: 10, order: "DeviceReportedTime", reversed: false } },
        Args.parse(['test'], <<-EOS))
test:
  period: '2013-05-05 22:20:00 +0000,10'
EOS
  end

end
