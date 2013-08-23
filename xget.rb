#!/usr/bin/env ruby
require 'socket'

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

  def initialize io
    @io  = io
    @buf = []
  end

  def to_io
    @io
  end

  def << chunk
    @buf << chunk
  end

  def handle_read
    read = @io.read_nonblock 512
    emit :READ, read
  rescue IO::WaitReadable
    emit :WAITING
  rescue EOFError, Errno::ECONNRESET
    emit :CLOSED
  end

  def handle_write
    @buf.each do |x|
      @io.puts x
      emit :WROTE, x
    end
    @buf = []
  rescue EOFError, Errno::ECONNRESET
    emit :CLOSED
  end
end

class Bot
  attr_reader :stream

  def initialize
    @stream = nil
  end

  def start
    @stream = Stream.new(TCPSocket.new('irc.lolipower.org', 6667))
    @stream << "NICK bmp"
    @stream << "USER lain 0 * iwakura lain"

    @stream.on :CLOSED do
      exit
    end

    @stream.on :WAITING do
      print 'a'
    end

    @stream.on :READ do |read|
      puts read
    end

    loop do
      @stream.handle_read
      @stream.handle_write
    end
  end
end

if __FILE__ == $0 then
  test = Bot.new
  test.start
end

