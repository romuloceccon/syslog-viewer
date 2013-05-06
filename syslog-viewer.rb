require 'mysql2'
require 'time'
require 'optparse'

class Args

  def initialize(args)
    @offset = DateTime.now.offset
    @args = args
  end

  def self.parse(args)
    parser = self.new(args)
    parser.internal_parse
  end

  def parse_date_or_count(x)
    if x.match(/^[+-]?\d+$/)
      x.to_i
    else
      Time.parse(x).utc
    end
  end

  def fmt_date(d)
    d.strftime('%Y-%m-%d %H:%M:%S')
  end

  def internal_parse
    result = { }

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.summary_width = 22

      opts.on('-c', '--connect CONN', 'Connect to MySQL with',
          'username:password@hostname[:port]') do |v|
        unless m = v.match(/^(.*):(.*)@([\w.]*)(:(\d+))?$/)
          raise OptionParser::InvalidArgument, v
        end
        result[:database] = { :host => m[3], :username => m[1],
            :password => m[2], :port => m[5].to_i }
      end
      opts.on('-1', '--first-line', 'Outputs first line of every message') do |v|
        result[:first_line] = true
      end
      opts.on('-n', '--count COUNT', 'Displays last COUNT events (default: 10)') do |v|
        result[:count] = v.to_i
      end
      opts.on('-f', '--follow', 'Polls database periodically for new events') do |v|
        result[:follow] = true
      end
      opts.on('-o', '--host HOST', 'Filter messages from host HOST') do |v|
        result[:host] = v
      end
      opts.on('-t', '--tag TAG', 'Filter messages with tag TAG') do |v|
        result[:tag] = v
      end
      opts.on('-s', '--severity SEV',
          'Filter messages with severity SEV or greater (DEBUG,',
          'INFORMATIONAL, NOTICE, WARNING, ERROR, CRITICAL,',
          'ALERT, EMERGENCY). Option can be abbreviated to any',
          'substring matching the start of the option (for',
          'example: `W\' for WARNING)') do |v|
        sev = SEV_OPTIONS.select { |key, value| key.start_with?(v.upcase) }
        raise OptionParser::InvalidArgument unless sev.count == 1
        result[:severity] = sev.values[0]
      end
      opts.on('-p', '--period PERIOD',
          'Filter by period PERIOD. PERIOD can be specified as',
          'as two dates parseable by Ruby\'s Time.parse; or a',
          'date and a number `x\': `x\' events before the date are',
          'listed if the number is negative, and `x\' events',
          'after the date otherwise. `DeviceReportedTime\' column',
          'will be used for filtering and ordering; default is',
          'to use `Id\'. Cannot be used in conjunction with -f',
          'or -c. Examples:',
          '  2013-05-05 20:50:00,2013-05-05 21:00:00',
          '  2013-05-06 01:00:00 +0000,-10') do |v|
        p = v.split(',')
        p1 = p2 = nil
        if p.count > 2
          raise OptionParser::InvalidArgument, v
        end
        p1 = parse_date_or_count(p[0]) if p[0]
        p2 = parse_date_or_count(p[1]) if p[1]
        if p1.respond_to?(:strftime) && p2.respond_to?(:strftime) && p1 <= p2
          result[:period] = { conditions:
              "DeviceReportedTime >= '#{fmt_date(p1)}' AND DeviceReportedTime <= '#{fmt_date(p2)}'",
              order: 'DeviceReportedTime', reversed: false }
        elsif p1.respond_to?(:strftime) && Numeric === p2
          if p2 >= 0
            result[:period] = { conditions: "DeviceReportedTime >= '#{fmt_date(p1)}'",
                limit: p2, order: 'DeviceReportedTime', reversed: false }
          else
            result[:period] = { conditions: "DeviceReportedTime <= '#{fmt_date(p1)}'",
                limit: -p2, order: 'DeviceReportedTime DESC', reversed: true }
          end
        else
          raise OptionParser::InvalidArgument, v
        end
      end

      opts.on('-h', '--help', 'Displays this help') do
        puts opts
        exit(0)
      end
    end

    parser.parse!(@args)

    if result[:period] && result[:follow]
      raise OptionParser::InvalidOption,
          '--period not allowed in conjunction with --follow'
    end
    if result[:period] && result[:count]
      raise OptionParser::InvalidOption,
          '--period not allowed in conjunction with --count'
    end

    result
  end

end

SEVERITIES = {
  0 => "\e[1;31mEME\e[0m",
  1 => "\e[1;35mALE\e[0m",
  2 => "\e[0;31mCRI\e[0m",
  3 => "\e[0;35mERR\e[0m",
  4 => "\e[0;33mWAR\e[0m",
  5 => "\e[0;32mNOT\e[0m",
  6 => "\e[0;36mINF\e[0m",
  7 => "\e[0;34mDEB\e[0m"
}

SEV_OPTIONS = {
  'EMERGENCY'     => 0,
  'ALERT'         => 1,
  'CRITICAL'      => 2,
  'ERROR'         => 3,
  'WARNING'       => 4,
  'NOTICE'        => 5,
  'INFORMATIONAL' => 6,
  'DEBUG'         => 7
}

FACILITIES = {
  0 =>  'KERN  ',
  1 =>  'USER  ',
  2 =>  'MAIL  ',
  3 =>  'DAEMON',
  4 =>  'AUTH  ',
  5 =>  'SYSLOG',
  6 =>  'LPR   ',
  7 =>  'NEWS  ',
  8 =>  'UUCP  ',
  9 =>  'CRON  ',
  10 => 'SECURI',
  11 => 'FTP   ',
  12 => 'NTP   ',
  13 => 'LOGAUD',
  14 => 'LOGALE',
  15 => 'CLOCK ',
  16 => 'LOCAL0',
  17 => 'LOCAL1',
  18 => 'LOCAL2',
  19 => 'LOCAL3',
  20 => 'LOCAL4',
  21 => 'LOCAL5',
  22 => 'LOCAL6',
  23 => 'LOCAL7'
}

class Application

  def initialize(options)
    @options = options.dup
    @options[:count] = 10 unless @options[:count]
    @options[:database] = { } unless @options[:database]

    @cols = `stty size`.strip.split[1].to_i

    @client = Mysql2::Client.new({ database: 'Syslog', database_timezone: :utc,
        application_timezone: :local }.merge(@options[:database]))

    @message_width = [@cols - 'dd/mm HH:MM:SS hhhhhh ttttttttttttttt FACILI SEV '.size, 30].max
    @max_id = 0

    @conditions = []

    if h = @options[:host]
      @conditions << "fromhost like '#{sanitize_str(h)}%'"
    end
    if t = @options[:tag]
      @conditions << "syslogtag like '#{sanitize_str(t)}%'"
    end
    if sev = @options[:severity]
      @conditions << "priority <= #{sev}"
    end
  end

  def run
    if period = @options[:period]
      output_results(exec_query({ limit: period[:limit],
          where: @conditions + [period[:conditions]], order: period[:order] }),
          period[:reversed])
      exit(0)
    end

    output_results(exec_query({ limit: @options[:count], where: @conditions }))

    if @options[:follow]
      while true do
        sleep(2.0)
        output_results(exec_query({ where: @conditions + ["id > #{@max_id}"] }))
      end
    end
  end

  def sanitize_str(s)
    s.gsub!("'", "''")
    s.gsub!("%", "%%")
    s
  end

  def exec_query(options = {})
    where = ""
    limit = ""
    order = "order by id desc"
    if w = options[:where]
      if w.respond_to?(:join)
        unless w.empty?
          where = "where #{w.join(' and ')}"
        end
      else
        where = w
      end
    end
    if options[:limit]
      limit = "limit #{options[:limit]}"
    end
    if options[:order]
      order = "order by #{options[:order]}"
    end
    @client.query(<<-EOS)
      select id, DeviceReportedTime, facility, priority, fromhost, syslogtag, message
      from SystemEvents #{where} #{order} #{limit}
    EOS
  end

  def output_message(message, width_of_first_line)
    lines = message.split("\n")

    if lines.empty?
      puts ""
      return
    end

    puts lines.first.slice!(0, width_of_first_line)
    return if @options[:first_line]

    while !lines.empty? do
      while (s = lines.first.slice!(0, @message_width)) != '' do
        print ' ' * (@cols - @message_width)
        puts s
      end
      lines.shift
    end
  end

  def output_results(arr, reversed = true)
    each_method = reversed ? :reverse_each : :each
    arr.send(each_method) do |row|
      @max_id = row['id']
      dt = row['DeviceReportedTime'].strftime('%d/%m %H:%M:%S')
      facility = FACILITIES[row['facility']] || '      '
      priority = SEVERITIES[row['priority']] || '   '
      host = "%-6s" % row['fromhost'].to_s[0..5]
      if m = row['syslogtag'].match(/^(.*)\[/)
        tag = "%-15s" % m[1].to_s[0..14]
      else
        tag = "%-15s" % row['syslogtag'].to_s[0..14]
      end
      remaining_len = @cols
      print dt;  remaining_len -= dt.size
      print ' '; remaining_len -= 1
      print host; remaining_len -= host.size
      print ' '; remaining_len -= 1
      print tag;  remaining_len -= tag.size
      print ' '; remaining_len -= 1
      print facility; remaining_len -= facility.size
      print ' '; remaining_len -= 1
      print priority; remaining_len -= 3
      print ' '; remaining_len -= 1
      msg = row['message'].gsub(/#\d{3}/) { |x| Integer(x[1..3]).chr }
      msg.slice!(0, 1) if msg[0] == ' '
      output_message(msg, remaining_len)
    end
  end

end

if __FILE__ == $0
  app = Application.new(Args.parse(ARGV))
  app.run
end
