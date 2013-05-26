#!/usr/bin/env ruby
%w(socket thread slop).each { |r| require r }

_serv = "irc.lolipower.org"
_chan = nil
_bot  = "Ginpachi-Sensei"
_pack = 1

config = {}
ident_sent = motd_end = nick_sent = nick_check = nick_valid = false

$xdcc_sent = $xdcc_accept = $xdcc_no_accept = false
$xdcc_accept_time = $xdcc_ret = nil

class XDCC_SEND
	attr_accessor :fname, :fsize, :ip, :port

	def initialize fname, fsize, ip, port
		@fname = fname
		@fsize = fsize
		@ip    = ip
		@port  = port
	end

	def put
		puts "[ #{self.fname}, #{self.fsize}, #{self.ip}, #{self.port}"
	end
end

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

	def put
		puts "[ #{self.serv}, #{self.chan}, #{self.bot}, #{self.pack}, #{self.info} ]"
	end
end

def bytes_to_closest bytes
	fsize_arr = [ 'B', 'KB', 'MB', 'GB', 'TB' ]
	exp       = (Math.log(bytes) / Math.log(1024)).to_i
	exp       = fsize_arr.length if exp > fsize_arr.length
	bytes    /= 1024 ** exp
	return "#{bytes}#{fsize_arr[exp]}"
end

def safe_fname fname
	return fname if not File.exists? fname

	ext  = File.extname fname
	base = File.basename(fname, ext)
	cur  = 2
	while true
		test = "#{base} (#{cur})#{ext}"
		return test if not File.exists? test
		cur += 1
	end
end

def dcc_download ip, port, fname, fsize, read = 0
	fh   = File.open fname, (read == 0 ? "w" : "a")
	sock = TCPSocket.new ip, port

	fsize_clean = bytes_to_closest fsize

	print "Downloading... "
	while buf = sock.readpartial(8192)
		read += buf.bytesize
		print "\r\e[0KDownloading... #{bytes_to_closest read}/#{fsize_clean} @ #{buf.bytesize}B"

		begin
			sock.write_nonblock [read].pack('N')
		rescue Errno::EWOULDBLOCK
		end

		fh << buf
		break if read >= fsize
	end

	sock.close
	fh.close

	$xdcc_sent = false
	$xdcc_accept = $xdcc_no_accept = false
	$xdcc_accept_time = $xdcc_ret = nil

	puts " - SUCCESS: #{fname} downloaded"
	return true
rescue EOFError
	puts " - FAILED: #{fname} unsuccessful"
	return false
end

if __FILE__ == $0
	opts = Slop.parse! do
		banner ' Usage: xget.rb [options] [value] [links] [--files] [file1:file2:file3]'
		on :help, :ignore_case => true

		on 'v', 'version', 'Print version' do
			puts "xget: version 0.0.0"
			exit
		end

		on 'config=',   'Config file location'
		on 'user=',     'IRC \'USER\' for Ident'
		on 'nick=',     'IRC nick'
		on 'pass=',     'IRC \'PASS\' for Ident'
		on 'realname=', 'Realname for \'USER\' Ident'
		on 'nickserv=', 'Password for Nickserv'
		on 'files=',    'Pass list of files to parse for links', as: Array, delimiter: ':'
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

	config_loc = opts["config"]
	if config_loc == nil or not File.exists? config_loc
		config_loc = File.expand_path "~/.xget.conf"
		config_loc = ".xget.conf" if not File.exists? config_loc
	end

	cur_block = "*"
	config[cur_block] = {}
	%w(user nick pass realname nickserv).each { |x| config[cur_block][x] = opts[x] unless opts[x] == nil }

	config_copies = {}
	File.open(config_loc, "r").each_line do |line|
		next if line.length <= 1 or line[0] == '#'

		if line =~ /^\[(.*)\]$/
			cur_block = $1
			if cur_block.include? ','
				tmp_split = cur_block.split(",")
				next unless tmp_split[0] =~ /^(\w+?).(\w+?).(\w+?)$/
				config_copies[tmp_split[0]] = []
				tmp_split.each do |x|
					next if x == tmp_split[0] or not x =~ /^(\w+?).(\w+?).(\w+?)$/
					config_copies[tmp_split[0]].push(x) unless config_copies[tmp_split[0]].include? x
				end
				cur_block = tmp_split[0]
			end
			config[cur_block] = {} unless config.has_key? cur_block
		elsif line =~ /^(\w+?)=(.*)$/
			config[cur_block][$1] = $2 unless config[cur_block].has_key? $1
		end
	end
	config_copies.each { |k,v| v.each { |x| config[x] = config[k] } } unless config_copies.empty?

	to_check = ARGV
	unless opts['files'] == nil or opts['files'].empty?
		opts['files'].each do |x|
			File.open(x, "r").each_line { |y| to_check << y.chomp } if File.exists? x
		end
	end

	tmp_range = requests = []
	to_check.each do |x|
		if x =~ /^(\w+?).(\w+?).(\w+?)\/#(\w+?)\/(\w+?)\/(.*)$/
			serv = [$1, $2, $3].join(".")
			info = (config.has_key?(serv) ? serv : "*")
			chan = "##{$4}"
			bot  = $5
			pack = case $6
				when /^(\d+?)$/
					$1.to_i
				when /^(\d+?)..(\d+?)$/
					if $1 > $2 or $1 == $2
						puts "! ERROR: Invalid range #{$1} to #{$2} in \"#{x}\""
						next
					end

					tmp_range =* ($1.to_i + 1)..$2.to_i
					$1.to_i
				else
					puts "! ERROR: Invalid pack ID in \"#{x}\""
					next
				end
			requests.push XDCC_REQ.new serv, chan, bot, pack, info

			if not tmp_range.empty?
				tmp_range.each { |y| requests.push XDCC_REQ.new serv, chan, bot, y, info }
				tmp_range.clear
			end
		else
			abort "! ERROR: #{x} is not a valid XDCC address\n         XDCC Address format: irc.serv.com/#chan/bot/pack"
		end
	end

	i = j = 0
	to_pop = []
	requests.each do |x|
		requests.each do |y|
			to_pop << j if x.eql? y if i != j
			j += 1
		end
		i += 1
	end
	to_pop.each { |x| requests.delete_at(x) }
	requests.each { |x| x.put }

	exit

	sock = TCPSocket.open(_serv, 6667)

	t = Thread.new do
		while true do
			if motd_end and nick_check and not $xdcc_sent
				sleep 1 # Cool off before download
				sock.puts "PRIVMSG #{_bot} :XDCC SEND #{_pack}"
				$xdcc_sent = true
			end

			# Wait 3 seconds for a DCC ACCEPT response, if there isn't one, don't resume
			if $xdcc_sent and $xdcc_accept and $xdcc_accept_time != nil
				if (Time.now - $xdcc_accept_time).floor > 3
					$xdcc_no_accept = true
					puts "FAILED! Bot client doesn't support resume!"
				end
			end

			if $xdcc_sent and $xdcc_no_accept
				puts "Connecting to: #{_bot} @ #{$xdcc_ret.ip}:#{$xdcc_ret.port}"
				dcc_download $xdcc_ret.ip, $xdcc_ret.port, $xdcc_ret.fname, $xdcc_ret.fsize
			end
		end
	end

	until sock.eof? do
		full_msg = sock.gets
		#puts full_msg

		if full_msg[0] == ':'
			/^:(?<nick>.*) (?<type>.*) (?<chan>.*) :(?<msg>.*)$/ =~ full_msg
			#puts "#{nick} - #{type} - #{chan} - #{msg}"

			case type
			when "NOTICE"
				if not ident_sent
					if chan == "AUTH"
						if msg =~ /Checking Ident/i
							puts "! Sending ident..."
							sock.puts "PASS #{config["*"]["pass"]}"
							sock.puts "NICK #{config["*"]["nick"]}"
							sock.puts "USER #{config["*"]["user"]} 0 * #{config["*"]["realname"]}"
							ident_sent = true
						elsif msg =~ /No Ident response/i or msg =~ /Erroneous Nickname/i
							puts "! ERROR: Ident failed"
							sock.puts 'QUIT'
						end
						puts "> #{msg}"
					end
				else
					if nick =~ /^NickServ!(.*)$/
						if not nick_sent and config["*"]["nickserv"] != nil
							sock.puts "PRIVMSG NickServ :IDENTIFY #{config["*"]["nickserv"]}"
							nick_sent = true
						elsif nick_sent and not nick_check
							if msg =~ /Password incorrect/i
								nick_valid = false
								nick_check = true
							elsif msg =~ /Password accepted/i
								nick_valid = true
								nick_check = true
							end
						end
						puts "> #{msg}"
					elsif nick =~ /^#{_bot}!(.*)$/i
						if msg =~ /already requested that pack/i
							puts "! ERROR: #{msg}"
							sock.puts "PRIVMSG #{_bot} :XDCC cancel"
							sock.puts 'QUIT'
						elsif msg =~ /you have a dcc pending/i
							puts "! ERROR: #{msg} - cancelling pending"
							sock.puts "PRIVMSG #{_bot} :xdcc cancel"
						else
							puts "! #{nick}: #{msg}"
						end
					end
				end
			when "PRIVMSG"
				puts full_msg
				if $xdcc_sent and nick =~ /^#{_bot}!(.*)$/i
					if msg =~ /^\001DCC SEND (.*) (.*) (.*) (.*)$/
						tmp_fname = fname = $1
						ip        = [$2.to_i].pack('N').unpack('C4') * '.'
						port      =  $3.to_i
						fsize     =  $4.to_i
						fname     =  $1 if fname =~ /^"(.*)"$/
						$xdcc_ret = XDCC_SEND.new fname, fsize, ip, port

						if File.exists? $xdcc_ret.fname and File.stat($xdcc_ret.fname).size < $xdcc_ret.fsize
							sock.puts "PRIVMSG #{_bot} :\001DCC RESUME #{tmp_fname} #{$xdcc_ret.port} #{File.stat($xdcc_ret.fname).size}\001"
							$xdcc_accept = true
							$xdcc_accept_time = Time.now
							print "! Incomplete file detected. Attempting to resume..."
							next # Skip and wait for "DCC ACCEPT"
						elsif File.exists? $xdcc_ret.fname
							$xdcc_ret.fname = safe_fname $xdcc_ret.fname
						end

						Thread.new do
							puts "Connecting to: #{_bot} @ #{$xdcc_ret.ip}:#{$xdcc_ret.port}"
							dcc_download $xdcc_ret.ip, $xdcc_ret.port, $xdcc_ret.fname, $xdcc_ret.fsize
						end
					elsif $xdcc_accept and $xdcc_ret != nil and not $xdcc_no_accept and msg =~ /^\001DCC ACCEPT (.*) (.*) (.*)$/
						$xdcc_accept_time = 0
						puts "SUCCESS!"

						Thread.new do
							puts "Connecting to: #{_bot} @ #{$xdcc_ret.ip}:#{$xdcc_ret.port}"
							dcc_download $xdcc_ret.ip, $xdcc_ret.port, $xdcc_ret.fname, $xdcc_ret.fsize, File.stat($xdcc_ret.fname).size
						end
					else
						puts "! ERROR: #{msg}"
						sock.puts 'QUIT'
					end
				end
			when /^\d+?$/
				type_i = type.to_i
				case type_i
				when 1
					puts "! #{msg}"
				when 376
					motd_end = true
				when 400..533
					next if not ident_sent or type_i == 439 # Skip 439
					puts "! ERROR: #{msg}"
					sock.puts 'QUIT'
				end
			end
		else
			sock.puts "PONG :#{$1}" if full_msg =~ /^PING :(.*)$/
		end
	end
	Thread.kill(t)
end

