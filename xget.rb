#!/usr/bin/env ruby

begin
  %w(socket thread slop timeout).each { |r| require r }
  require 'Win32/Console/ANSI' if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
rescue LoadError
  abort "#{$0} requires slop and, if you're on Windows, win32console\nPlease run 'gem install slop win32console'"
end

# Why isn't this enabled by default?
Thread.abort_on_exception = true

# Version values
ver_maj, ver_min, ver_rev = 2, 0, 0
ver_str = "#{ver_maj}.#{ver_min}.#{ver_rev}"

config = {
  "out-dir"       => './',
  "skip-existing" => false,
  "servers"       => {} }

def puts_error msg
  puts "! \e[31mERROR\e[0m: #{msg}"
end

def puts_abort msg
  abort "! \e[31mERROR\e[0m: #{msg}"
end

def puts_warning msg
  puts "! \e[33mWARNING:\e[0m: #{msg}"
end

class IO
  def gets_nonblock
    @rlnb_buffer ||= ""
    ch = nil
    while ch = self.read_nonblock(1)
      @rlnb_buffer += ch
      if ch == "\n" then
        res  = @rlnb_buffer
        @rlnb_buffer = ""
        return res
      end
    end
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

module Emitter
  def callbacks
    @callbacks ||= Hash.new { |h, k| h[k] = [] }
  end

  def on type, &block
    callbacks[type] << block
    self
  end

  def emit type, *args
    callbacks[type].each do |block|
      block.call(*args)
    end
  end
end

class Stream
  include Emitter
  attr_accessor :io, :buf

  def initialize serv
    @buf = []
    @io  = TCPSocket.new serv, 6667
  rescue SocketError => e
    puts_abort "Failed to connect to #{serv}! #{e.message}"
  end

  def disconnect
    @io.puts 'QUIT'
  end

  def << data
    @buf << data
  end

  def write
    @buf.each do |x|
      @io.puts x
      emit :WROTE, x
    end
    @buf = []
  rescue EOFError, Errno::ECONNRESET
    emit :CLOSED
  end

  def read
    read = @io.gets_nonblock
    emit :READ, read
  rescue IO::WaitReadable
    emit :WAITING
  rescue EOFError, Errno::ECONNRESET
    emit :CLOSED
  end
end

class Bot
  attr_reader :stream

  def initialize stream
    @stream = stream
    stream.on :CLOSED do stop; end
  end

  def start
    @running = true
    tick while @running
  end

  def stop
    @running = false
  end

  def tick
    stream.read
    stream.write
  end
end

if __FILE__ == $0 then
  opts = Slop.parse! do
    banner " Usage: #{$0} [options] [value] [links] [--files] [file1:file2:file3]\n"
    on :help, :ignore_case => true

    on 'v', 'version', 'Print version' do
      puts "#{$0}: v#{ver_str}"
      exit
    end

    on 'config=',       'Config file location'
    on 'user=',         'IRC \'USER\' for Ident'
    on 'nick=',         'IRC nick'
    on 'pass=',         'IRC \'PASS\' for Ident'
    on 'realname=',     'Realname for \'USER\' Ident'
    on 'nickserv=',     'Password for Nickserv'
    on 'files=',        'Pass list of files to parse for links',   as: Array, delimiter: ':'
    on 'out-dir=',      'Output directory to save fiels to',       :default => "./"
    on 'skip-existing', 'Don\' download files that already exist', :default => false
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
  config["servers"][cur_block] = {}
  %w(user nick pass real nserv).each do |x|
    config["servers"][cur_block][x.to_sym] = opts[x] unless opts[x].nil?
  end

  # Check if specified output directory actually exists
  puts_abort "Out directory, \"#{opts["out-dir"]}\" doesn't exist!" unless Dir.exists? opts["out-dir"]
  config["out-dir"] = opts["out-dir"].dup
  config["out-dir"] << "/" unless config["out-dir"][-1] == "/"

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
      config["servers"][cur_block] = {} unless config["servers"].has_key? cur_block
    elsif line =~ /^(\S+)=(.*+?)$/
      # Check if current line is specifying out directory
      case $1
      when "out-dir"
        t_out_dir = File.expand_path $2
        puts_abort "Out directory, \"#{t_out_dir}\" doesn't exist!" unless Dir.exists? t_out_dir
        config[$1] = t_out_dir
        config[$1] << "/" unless config[$1][-1] == "/"
        next
      when "skip-existing" then config[$1] = ($2 == "true")
      else
        # Add value to current header, default is *
        t_sym = $1.downcase.to_sym
        config["servers"][cur_block][t_sym] = $2 unless config["servers"][cur_block].has_key? t_sym
      end
    end
  end

  # Go through each and make copies of the original
  unless config_copies.empty?
    config_copies.each do |k,v|
      v.each { |x| config["servers"][x] = config["servers"][k] }
    end
  end

  # Take remaining arguments and all lines from --files arg and put into array
  to_check = ($*)
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
      info = (config["servers"].has_key?(serv) ? serv : "*")
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
        rmp_range.each { |y| tmp_requests.push XDCC_REQ.new serv, chan, bot, y, info }
        tmp_range.clear
      end
    else
      puts_abort "#{x} is not a valid XDCC address\n XDCC Address format: irc.serv.com/#chan/bot/pack"
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

  requests.each do |k, v|
    req, info, motd = v[0], config["servers"][v[0].info], false
    nick_sent, nick_check, nick_valid = false, false, false

    stream  = Stream.new req.serv
    stream << "PASS #{info[:pass]}" unless info[:pass].nil?
    stream << "NICK #{info[:nick]}"
    stream << "USER #{info[:user]} 0 * #{info[:real]}"

    stream.on :READ do |data|
      /^(?:[:](?<prefix>\S+) )?(?<type>\S+)(?: (?!:)(?<dest>.+?))?(?: [:](?<msg>.+))?$/ =~ data
      puts ">> #{prefix} | #{type} | #{dest} | #{msg}"

      case type
      when 'NOTICE'
        if dest == 'AUTH'
          if msg =~ /erroneous nickname/i
            puts_error 'Login failed'
            stream.disconnect
          end
        else
          if prefix =~ /^NickServ!/
            if not nick_sent and info[:nserv] != nil
              stream << "PRIVMSG NickServ :IDENTIFY #{info[:nserv]}"
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
          elsif prefix =~ /^#{Regexp.escape req.bot}!(.*)$/i
            case msg
            when /already requested that pack/i, /closing connection/i, /you have a dcc pending/i, /you can only have (\d+?) transfer at a time/i
              puts_error msg
              stream << "PRIVMSG #{req.bot} :XDCC CANCEL"
              stream << 'QUIT'
            else
              puts "! #{prefix}: #{msg}"
            end
          end
        end
      when 'PRIVMSG'
      when /^\d+?$/
        type_i = type.to_i
        case type_i
        when 1 # Print welcome message, because it's nice
          msg.sub!(/#{Regexp.escape info[:nick]}/, "\e[34m#{info[:nick]}\e[0m")
          puts "! #{msg}"
        when 400..533 # Handle errors, except 439
          next if type_i == 439 # Skip 439
          puts_error "#{msg}"
          stream.disconnect
        when 376 then motd = true # Mark the end of the MOTD
        end
      when 'PING'  then stream << "PONG :#{msg}"
      when 'ERROR' then (msg =~ /closing link/i ? puts(msg) : puts_error(msg))
      end
    end

    stream.on :WAITING do
    end

    stream.on :WROTE do |data|
      puts "<< #{data}"
    end

    bot = Bot.new stream
    bot.start
  end
end

