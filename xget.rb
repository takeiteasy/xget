#!/usr/bin/env ruby
require 'socket'

_serv = "irc.lolipower.org"
_chan = nil
_bot  = "Ginpachi-Sensei"
_pack = 41

config = {}
ident_sent = motd_end = nick_sent = nick_check = nick_valid = false
xdcc_sent = false

def bytes_to_closest(bytes)
	fsize_arr = [ 'B', 'KB', 'MB', 'GB', 'TB' ]
	exp       = (Math.log(bytes) / Math.log(1024)).to_i
	exp       = fsize_arr.length if exp > fsize_arr.length
	bytes    /= 1024 ** exp
	return "#{bytes}#{fsize_arr[exp]}"
end

def safe_fname(fname)
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

def dcc_download(ip, port, fname, fsize, read = 0)
	fh    = File.open(fname, (read == 0 ? "w" : "a"))
	sock  = TCPSocket.new(ip, port)

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

	puts " - SUCCESS: #{fname} downloaded"
	return true
rescue EOFError
	puts " - FAILED: #{fname} unsuccessful"
	return false
end

if __FILE__ == $0
	config_loc = File.expand_path "~/.xget.conf"
	config_loc = ".xget.conf" if not File.exists? config_loc

	check_line    = ->(x) { x.length > 1 and x[0] != '#' }
	proccess_line = ->(x) { config[$1] = $2 if not config.has_key? $1 if x =~ /^(\w+)=(.*)$/ }
	File.open(config_loc, "r").each_line.select(&check_line).each(&proccess_line) if File.exists? config_loc
	abort("! ERROR: No nick specified in config!") if config["nick"] == nil
	config["user"]     = config["nick"] if config["user"]            == nil
	config["realname"] = config["nick"] if config["realname"]        == nil

	sock = TCPSocket.open(_serv, 6667)
	until sock.eof? do
		full_msg = sock.gets
		puts full_msg

		if full_msg[0] == ':'
			/^:(?<nick>.*) (?<type>.*) (?<chan>.*) :(?<msg>.*)$/ =~ full_msg
			#puts "#{nick} - #{type} - #{chan} - #{msg}"

			case type
			when "NOTICE"
				if not ident_sent
					if chan == "AUTH"
						if msg =~ /Checking Ident/i
							puts "! Sending ident..."
							sock.puts "PASS #{config["pass"]}"
							sock.puts "NICK #{config["nick"]}"
							sock.puts "USER #{config["user"]} 0 * #{config["realname"]}"
							ident_sent = true
						elsif msg =~ /No Ident response/i or msg =~ /Erroneous Nickname/i
							puts "! ERROR: Ident failed"
							sock.puts 'QUIT'
						end
						puts "> #{msg}"
					end
				else
					if nick =~ /^NickServ!(.*)$/
						if not nick_sent and config["nickserv"] != nil
							sock.puts "PRIVMSG NickServ :IDENTIFY #{config["nickserv"]}"
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
						else
							puts "! #{nick}: #{msg}"
						end
					end
				end
			when "PRIVMSG"
				puts full_msg
				if xdcc_sent and nick =~ /^#{_bot}!(.*)$/i
					if msg =~ /^\001DCC SEND (.*) (.*) (.*) (.*)$/
						org_fname = fname = $1
						ip        = [$2.to_i].pack('N').unpack('C4') * '.'
						port      =  $3.to_i
						fsize     =  $4.to_i
						fname     =  $1 if fname =~ /"(.*)"/
						read_from =  0
						if File.exists? fname and File.stat(fname).size < fsize
							read_from = File.stat(fname).size
							sock.puts "PRIVMSG #{_bot} :\001DCC RESUME #{org_fname} #{port} #{read_from}\001"
						elsif File.exists? fname
							fname = safe_fname fname
						end

						t = Thread.new do
							puts "Connecting to: #{_bot} @ #{ip}:#{port}"
							dcc_download(ip, port, fname, fsize, read_from)
						end
					else
						puts "! ERROR: #{msg}"
						sock.puts 'QUIT'
					end
				end
			when /^\d+?$/
				case type.to_i
				when 1
					puts "! #{msg}"
				when 376
					motd_end = true
				when 400..533
					next if not ident_sent # Skip 439
					puts "! ERROR: #{msg}"
					sock.puts 'QUIT'
				end
			end
		else
			sock.puts "PONG #{$~[1]}" if msg =~ /^PING :(.*)$/
		end

		#if motd_end and nick_check and not xdcc_sent
			#sock.puts "PRIVMSG #{_bot} :XDCC SEND #{_pack}"
			#xdcc_sent = true
		#end
	end
end

