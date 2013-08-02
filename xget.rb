#!/usr/bin/env ruby

begin
  %w(socket thread slop timeout).each { |r| require r }
  require 'Win32/Console/ANSI' if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
rescue LoadError => e
  abort "#{$0} requires slop and, if you're on Windows, win32console\nPlease run 'gem install slop win32console'"
end

ver_maj = 1
ver_min = 3
ver_rev = 1
ver_str = "#{ver_maj}.#{ver_min}.#{ver_rev}"

config = {}
out_dir = "./"
skip_existing = false
ident_sent = motd_end = nick_sent = nick_check = nick_valid = false

$xdcc_sent = $xdcc_accept = $xdcc_no_accept = false
$xdcc_accept_time = $xdcc_ret = nil

# Don't ignore exceptions in threads
# I don't know why this isn't enabled by default
# This isn't fucking Python
Thread.abort_on_exception = true

# Class to hold DCC SEND info for when waiting for DCC ACCEPT
class XDCC_SEND
  attr_accessor :fname, :fsize, :ip, :port

  def initialize fname, fsize, ip, port
    @fname = fname
    @fsize = fsize
    @ip    = ip
    @port  = port
  end

  def to_s
    "[ #{self.fname}, #{self.fsize}, #{self.ip}, #{self.port} ]"
  end
end


# Class to hold XDCC requests
class XDCC_REQ
  attr_accessor :serv, :chan, :bot, :pack, :info

  def initialize serv, chan, bot, pack, info = "*"
    @serv = serv
    @chan = chan
    @bot  = bot
    @pack = pack
    @info = info
  end

  def eql? other
    self.serv == other.serv and self.chan == other.chan and self.bot == other.bot and self.pack == other.pack
  end

  def to_s
    "[ #{self.serv}, #{self.chan}, #{self.bot}, #{self.pack}, #{self.info} ]"
  end
end

# Extend array with averages method
class Array
  def average
    inject(:+) / count
  end
end

def puts_error msg
  puts "! \e[31mERROR\e[0m: #{msg}"
end

def puts_abort msg
  abort "! \e[31mERROR\e[0m: #{msg}"
end

def puts_warning msg
  puts "! \e[33mWARNING:\e[0m: #{msg}"
end

def bytes_to_closest bytes
  fsize_arr = [ 'B', 'KB', 'MB', 'GB', 'TB' ]
  exp       = (Math.log(bytes) / Math.log(1024)).to_i
  exp       = fsize_arr.length if exp > fsize_arr.length
  bytes    /= 1024.0 ** exp
  return "#{bytes.round(2)}#{fsize_arr[exp]}"
end

# Loop until there is no file with the same name
def safe_fname fname
  return fname unless File.exists? fname

  ext  = File.extname fname
  base = File.basename fname, ext
  dir  = File.dirname fname

  cur  = 2
  while true
    test = "#{dir}/#{base} (#{cur})#{ext}"
    return test unless File.exists? test
    cur += 1
  end
end

# Get a close relative time remaining, in words
def time_distance t
  if t < 60
    case t
    when 0      then "- nevermind, done!"
    when 1..4   then "in a moment!"
    when 5..9   then "less than 10 seconds"
    when 10..19 then "less than 20 seconds"
    when 20..39 then "half a minute"
    else "less than a minute"
    end
  else # Use minutes, to aovid big numbers
    t = t / 60.0
    case t.to_i
    when 1            then "about a minute"
    when 2..45        then "#{t.round} minutes"
    when 45..90       then "about an hour"
    when 91..1440     then "about #{(t / 60.0).round} hours"
    when 1441..2520   then "about a day"
    when 2521..86400  then "about #{(t / 1440.0).round} days"
    else "about #{(t/ 43200.0).round} months"
    end
  end
end

# Get elapsed time in words
def time_elapsed t
  return "instantly!" if t <= 0

  # Get the GMTime from seconds and split
  ta = Time.at(t).gmtime.strftime('%S|%M|%H|%-d|%-m|%Y').split('|', 6).collect { |i| i.to_i }
  ta[-1] -= 1970 # fuck the police
  ta[-2] -= 1    # fuck, fuck
  ta[-3] -= 1    # fuck the police

  # Remove the 0 digets
  i = 0
  ta.reverse.each do |x|
    break if x != 0
    i += 1
  end

  # Unit suffixes
  suffix = [ "seconds", "minutes", "hours", "days", "months", "years" ];
  # Don't use plural if x is 1
  plural     = ->(x, y) { x == 1 ? y[0..-2] : y }
  # Format string to "value unit"
  format_str = ->(x)    { "#{ta[x]} #{plural[ta[x], suffix[x]]}, " }

  # Form the string
  ta = ta.take(ta.length - i)
  str = ""
  (ta.length - 1).downto(0) { |x| str += format_str[x] }
  "in #{str[0..-3]}"
end

def dcc_download ip, port, fname, fsize, read = 0
  sock = nil
  begin
    Timeout::timeout(10) { sock = TCPSocket.new ip, port }
  rescue SocketError => e
    puts_abort "Failed to connect to \"#{ip}:#{port}\": #{e}"
  rescue Timeout::Error => e
    puts_abort "Connect to #{ip}:#{port} timed out! #{e}"
  end
  puts_abort "Failed to connect to \"#{ip}:#{port}\": #{e}" if sock.nil?

  begin
    ready = IO.select([sock], nil, [sock], 3)
    raise Timeout::Error unless ready
  rescue IOError, Timeout::Error => e
    puts_abort "Connect to #{ip}:#{port} timed out! #{e}"
  end

  fsize_clean = bytes_to_closest fsize
  avgs, last_check, start_time = [], Time.now - 2, Time.now
  fh = File.open fname, (read == 0 ? "w" : "a") # Write or append

  # Form the status bar
  print_bar = ->() {
    print "\r\e[0K> [ \e[1;37m"
    pc = read.to_f / fsize.to_f * 100.0
    bars = (pc / 10).to_i
    bars.times { print "#" }
    (10 - bars).times { print " " }
    avg = avgs.average * 1024.0
    time_rem = time_distance ((fsize - read) / avg) * 8.0
    print "\e[0m ] #{pc.round(2)}% #{bytes_to_closest read}/#{fsize_clean} \e[1;37m@\e[0m #{bytes_to_closest avg}/s \e[1;37min\e[0m #{time_rem}"

    last_check = Time.now
    avgs.clear
  }

  while buf = sock.readpartial(8192)
    read += buf.bytesize
    avgs << buf.bytesize
    print_bar[] if (Time.now - last_check) > 1 and not avgs.empty?

    begin
      sock.write_nonblock [read].pack('N')
    rescue Errno::EWOULDBLOCK
    rescue Errno::EAGAIN => e
      puts_error "#{File.basename fname} timed out! #{e}"
    end

    fh << buf
    break if read >= fsize
  end
  print_bar.call unless avgs.empty?
  elapsed_time = time_elapsed (Time.now - start_time).to_i

  sock.close
  fh.close
  ready = nil

  $xdcc_sent = false
  $xdcc_accept = $xdcc_no_accept = false
  $xdcc_accept_time = $xdcc_ret = nil

  puts "\n! \e[1;32mSUCCESS\e[0m: downloaded #{File.basename fname} #{elapsed_time}"
rescue EOFError, SocketError => e
  puts "\n! ERROR: #{File.basename fname} failed to download! #{e}"
end

if __FILE__ == $0
  opts = Slop.parse! do
    banner " Usage: #{$0} [options] [value] [links] [--files] [file1:file2:file3]\n"
    on :help, :ignore_case => true

    on 'v', 'version', 'Print version' do
      puts "#{$0}: v#{ver_str}"
      exit
    end

    on 'config=',      'Config file location'
    on 'user=',        'IRC \'USER\' for Ident'
    on 'nick=',        'IRC nick'
    on 'pass=',        'IRC \'PASS\' for Ident'
    on 'realname=',    'Realname for \'USER\' Ident'
    on 'nickserv=',    'Password for Nickserv'
    on 'files=',       'Pass list of files to parse for links', as: Array, delimiter: ':'
    on 'out=',         'Output directory to save fiels to', :default => "./"
    on 'skip-existing' 'Don\' download files that already exist', :default => false
  end

  if opts.help?
    puts opts
    puts "\n Examples"
    puts " \txget.rb --config config.conf --nick test"
    puts " \txget.rb --files test1.txt:test2.txt:test3.txt"
    puts " \txget.rb irc.rizon.net/#news/ginpachi-sensei/1"
    puts " \txget.rb irc.rizon.net/#news/ginpachi-sensei/41..46"
    exit
  end

  # Get the config location
  config_loc = opts["config"]
  if config_loc.nil? or not File.exists? config_loc
    config_loc = File.expand_path "~/.xget.conf"
    config_loc = ".xget.conf" unless File.exists? config_loc
  end

  # Insert config settings from arguments into config hash
  cur_block = "*"
  config[cur_block] = {}
  %w(user nick pass realname nickserv).each { |x| config[cur_block][x.to_sym] = opts[x] unless opts[x].nil? }

  # Check if specified output directory actually exists
  puts_abort "Out directory, \"#{opts["out"]}\" doesn't exist!" unless Dir.exists? opts["out"]
  out_dir = opts["out"].dup
  out_dir << "/" unless out_dir[-1] == "/"

  # Parse config
  config_copies = {}
  File.open(config_loc, "r").each_line do |line|
    next if line.length <= 1 or line[0] == '#'

    if line =~ /^\[(\S+)\]$/ # Check if header
      cur_block = $1
      if cur_block.include? ',' # Check if header contains more than one server
        tmp_split = cur_block.split(",")
        next unless tmp_split[0] =~ /^(\w+?).(\w+?).(\w+?)$/
        config_copies[tmp_split[0]] = []
        tmp_split.each do |x| # Add all copies to copies hash
          next if x == tmp_split[0] or not x =~ /^(\w+?).(\w+?).(\w+?)$/
          config_copies[tmp_split[0]].push x unless config_copies[tmp_split[0]].include? x
        end
        cur_block = tmp_split[0]
      end

      # Set current block to the new header
      config[cur_block] = {} unless config.has_key? cur_block
    elsif line =~ /^(\S+)=(.*+?)$/
      # Check if current line is specifying out directory
      case $1
      when "out"
        t_out_dir = File.expand_path $2
        puts_abort "Out directory, \"#{t_out_dir}\" doesn't exist!" unless Dir.exists? t_out_dir
        out_dir = t_out_dir
        out_dir << "/" unless out_dir[-1] == "/"
        next
      when "skip-existing" then skip_existing == ($2 == "true")
      else
        # Add value to current header, default is *
        t_sym = $1.downcase.to_sym
        config[cur_block][t_sym] = $2 unless config[cur_block].has_key? t_sym
      end
    end
  end

  # Go through each and make copies of the original
  config_copies.each { |k,v| v.each { |x| config[x] = config[k] } } unless config_copies.empty?

  # Take remaining arguments and all lines from --files arg and put into array
  to_check = $*
  if opts['files'] != nil and not opts['files'].empty?
    opts['files'].each do |x|
      File.open(x, "r").each_line { |y| to_check << y.chomp } if File.exists? x
    end
  end

  if to_check.empty?
    puts opts
    abort "\n No jobs, nothing to do!"
  end

  # Parse to_check array for valid XDCC links, irc.serv.org/#chan/bot/pack
  tmp_requests, tmp_range = [], []
  to_check.each do |x|
    if x =~ /^(\w+?).(\w+?).(\w+?)\/#(\S+)\/(\S+)\/(\d+)(..\d+)?$/
      serv = [$1, $2, $3].join(".")
      info = (config.has_key?(serv) ? serv : "*")
      chan = "##{$4}"
      bot  = $5
      pack = $6.to_i
      unless $7.nil?
        to_range = $7[2..-1].to_i # Clip off the ".."
        if pack > to_range or pack == to_range
          puts_error "Invalid range #{pack} to #{to_range} in \"#{x}\""
          next
        end
        tmp_range =* (pack + 1)..to_range
      end
      tmp_requests.push XDCC_REQ.new serv, chan, bot, pack, info

      # Convert range array to new requests
      unless tmp_range.empty?
        tmp_range.each { |y| tmp_requests.push XDCC_REQ.new serv, chan, bot, y, info }
        tmp_range.clear
      end
    else
      puts_abort "#{x} is not a valid XDCC address\n         XDCC Address format: irc.serv.com/#chan/bot/pack"
    end
  end

  # Remove duplicate entries from requests
  i = j = 0
  to_pop = []
  tmp_requests.each do |x|
    tmp_requests.each do |y|
      to_pop << j if x.eql? y if i != j
      j += 1
    end
    i += 1
  end
  to_pop.each { |x| tmp_requests.delete_at(x) }

  # Sort requests array to hash, serv {} -> chan {} -> requests []
  requests = {}
  tmp_requests.each do |x|
    requests[x.serv] = [] unless requests.has_key? x.serv
    requests[x.serv] << x
  end

  if requests.empty?
    puts opts
    abort "\n No jobs, nothing to do!"
  end

  # Sort requests by pack
  requests.each do |k,v|
    puts "#{k} \e[1;37m->\e[0m"
    v = v.sort_by { |x| [x.chan, x.pack] }.each { |x| puts "\t#{x}" }
  end
  puts

  # Go through each server
  requests.each do |k, v|
    # Try and connect to the server
    sock = nil
    begin
      Timeout::timeout (10) { sock = TCPSocket.new k, 6667 }
    rescue SocketError => e
      puts_abort "Failed to connect to \"#{k}\": #{e}"
    rescue Timeout::Error => e
      puts_abort "Connect to #{k} timed out! #{e}"
    end
    cur_req, max_req, x, last_chan = -1, v.length, v[0], ""
    zero_time = Time.at 0
    req_send_time = zero_time

    # Message thread, to avoid blocking
    t = Thread.new do
      while true do
        # Send the next XDCC request
        if motd_end and not $xdcc_sent
          cur_req += 1
          if cur_req >= max_req
            sock.puts "QUIT" # Quit IRC server
            Thread.kill t    # Kill message thread
          end
          x = v[cur_req];

          if x.chan != last_chan
            sock.puts "PART #{last_chan}" unless last_chan == ""
            last_chan = x.chan
            sock.puts "JOIN #{x.chan}"
          end

          sleep 1 # Cool off before download
          sock.puts "PRIVMSG #{x.bot} :XDCC SEND #{x.pack}"
          req_send_time = Time.now
          $xdcc_sent = true
        end

        # Wait 3 seconds for DCC SEND response, if there isn't one, abort
        if $xdcc_sent and req_send_time > zero_time and not $xdcc_accept
          if (Time.now - req_send_time).floor > 3
            puts_error "#{x.bot} took too long to respond, are you sure it's a bot?"
            sock.puts 'QUIT'
            Thread.exit
          end
        end

        # Wait 3 seconds for a DCC ACCEPT response, if there isn't one, don't resume
        if $xdcc_sent and $xdcc_accept and $xdcc_accept_time > zero_time
          if (Time.now - $xdcc_accept_time).floor > 3
            $xdcc_no_accept = true
            puts "FAILED! Bot client doesn't support resume!"
          end
        end

        # XDCC bot's client doesn't support DCC RESUME, start from beginning
        if $xdcc_sent and $xdcc_no_accept
          puts "Connecting to: #{x.bot} @ #{$xdcc_ret.ip}:#{$xdcc_ret.port}"
          dcc_download $xdcc_ret.ip, $xdcc_ret.port, $xdcc_ret.fname, $xdcc_ret.fsize
        end
      end
    end

    # H-here w-w-we g-go...
    until sock.eof? do
      /^(?:[:](?<prefix>\S+) )?(?<type>\S+)(?: (?!:)(?<dest>.+?))?(?: [:](?<msg>.+))?$/ =~ sock.gets
      #puts "#{prefix} | #{type} | #{dest} | #{msg}"

      case type
      when "NOTICE"
        unless ident_sent
          if dest == "AUTH"
            case msg
            when /checking ident/i
              puts "! Sending login..."
              sock.puts "PASS #{config[x.info][:pass]}" unless config[x.info][:pass].nil?
              sock.puts "NICK #{config[x.info][:nick]}"
              sock.puts "USER #{config[x.info][:user]} 0 * #{config[x.info][:realname]}"
              ident_sent = true
            when /no ident response/i, /erroneous nickname/i
              puts_error "Ident failed"
              sock.puts 'QUIT'
            end
            puts "> \e[1;32m#{msg}\e[0m"
          end
        else
          if prefix =~ /^NickServ!/
            if not nick_sent and config[x.info][:nickserv] != nil
              sock.puts "PRIVMSG NickServ :IDENTIFY #{config[x.info][:nickserv]}"
              nick_sent = true
            elsif nick_sent and not nick_check
              case msg
              when /password incorrect/i
                nick_valid = false
                nick_check = true
              when /password accepted/i
                nick_valid = true
                nick_check = true
              end
            end
            puts "> \e[1;33m#{msg}\e[0m"
          elsif prefix =~ /^#{Regexp.escape x.bot}!(.*)$/i
            case msg
            when /already requested that pack/i, /closing connection/i, /you have a dcc pending/i, /you can only have (\d+?) transfer at a time/i
              puts_error msg
              sock.puts "PRIVMSG #{x.bot} :XDCC CANCEL"
              sock.puts 'QUIT'
            else
              puts "! #{prefix}: #{msg}"
            end
          end
        end
      when "PRIVMSG"
        if $xdcc_sent and not $xdcc_accept and prefix =~ /^#{Regexp.escape x.bot}!(.*)$/i
          /^\001DCC SEND (?<fname>((".*?").*?|(\S+))) (?<ip>\d+) (?<port>\d+) (?<fsize>\d+)\001\015$/ =~ msg

          if $~.nil?
            puts msg.bytes.to_a
            puts_error msg
            sock.puts 'QUIT'
          end
          req_send_time = zero_time # It's a valid bot

          tmp_fname = fname
          fname     =  $1 if tmp_fname =~ /^"(.*)"$/
          puts "Preparing to download: \e[36m#{fname}\e[0m"
          fname     = (out_dir.dup << fname)
          $xdcc_ret = XDCC_SEND.new fname, fsize.to_i, [ip.to_i].pack('N').unpack('C4') * '.', port.to_i

          # Check if the for unfinished download amd try to resume
          if File.exists? $xdcc_ret.fname and File.stat($xdcc_ret.fname).size < $xdcc_ret.fsize
            sock.puts "PRIVMSG #{x.bot} :\001DCC RESUME #{tmp_fname} #{$xdcc_ret.port} #{File.stat($xdcc_ret.fname).size}\001"
            $xdcc_accept = true
            $xdcc_accept_time = Time.now
            print "! Incomplete file detected. Attempting to resume..."
            next # Skip and wait for "DCC ACCEPT"
          elsif File.exists? $xdcc_ret.fname
            if skip_existing
              puts_warning "File already exists, skipping..."
              sock.puts "PRIVMSG #{x.bot} :XDCC CANCEL"

              $xdcc_sent = false
              $xdcc_accept = $xdcc_no_accept = false
              $xdcc_accept_time = $xdcc_ret = nil
              next
            else
              puts_warnings "File already existing, using a safe name..."
              $xdcc_ret.fname = safe_fname $xdcc_ret.fname
            end
          end

          # It's a new download, start from beginning
          Thread.new do
            puts "Connecting to: #{x.bot} @ #{$xdcc_ret.ip}:#{$xdcc_ret.port}"
            dcc_download $xdcc_ret.ip, $xdcc_ret.port, $xdcc_ret.fname, $xdcc_ret.fsize
          end
        elsif $xdcc_accept and $xdcc_ret != nil and not $xdcc_no_accept and msg =~ /^\001DCC ACCEPT ((".*?").*?|(\S+)) (\d+) (\d+)\001\015$/
          # DCC RESUME request accepted, continue the download!
          $xdcc_accept_time = nil
          $xdcc_accept = false
          puts "\e[1;32mSUCCESS\e[0m!"

          Thread.new do
            puts "Connecting to: #{x.bot} @ #{$xdcc_ret.ip}:#{$xdcc_ret.port}"
            dcc_download $xdcc_ret.ip, $xdcc_ret.port, $xdcc_ret.fname, $xdcc_ret.fsize, File.stat($xdcc_ret.fname).size
          end
        end
      when /^\d+?$/
        type_i = type.to_i
        case type_i
        when 1 # Print welcome message, because it's nice
          msg.sub!(/#{Regexp.escape config[x.info][:nick]}/, "\e[34m#{config[x.info][:nick]}\e[0m")
          puts "! #{msg}"
        when 376 # Mark the end of the MOTD
          motd_end = true
        when 400..533 # Handle errors, except 439
          next if type_i == 439 # Skip 439
          puts_error "#{msg}"
          sock.puts 'QUIT'
        end
      when "PING"  then sock.puts "PONG :#{msg}"
      when "ERROR" then (msg =~ /closing link/i ? puts(msg) : puts_error(msg))
      end
    end
  end
end

