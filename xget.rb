#!/usr/bin/env ruby

config = {}

if __FILE__ == $0
	config_loc = File.expand_path "~/.xget.conf"
	config_loc = ".xget.conf" if not File.exists? config_loc

	check_line    = ->(x) { x.length > 1 and x[0] != '#' }
	proccess_line = ->(x) { config[$1] = $2 if not config.has_key? $1 if x =~ /^(\w+)=(.*)$/ }
	File.open(config_loc, "r").each_line.select(&check_line).each(&proccess_line) if File.exists? config_loc
end

