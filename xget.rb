#!/usr/bin/env ruby
require 'socket'

_serv = "irc.lolipower.org"
_chan = nil
_bot  = "Ginpachi-Sensei"
_pack = 1

config = {}
ident_sent = motd_end = nick_sent = nick_check = nick_valid = false

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
		if full_msg[0] == ':'
			/^:(?<nick>.*) (?<type>.*) (?<chan>.*) :(?<msg>.*)$/ =~ full_msg
			puts "#{nick} - #{type} - #{chan} - #{msg}"

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
	end
end

