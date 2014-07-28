#! /your/favourite/path/to/ruby
# -*- coding: utf-8; mode: ruby; ruby-indent-level: 2 -*-
#
# Copyright (c) 2014 Urabe, Shyouhei
#
# Permission is hereby granted, free of  charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction,  including without limitation the rights
# to use,  copy, modify,  merge, publish,  distribute, sublicense,  and/or sell
# copies  of the  Software,  and to  permit  persons to  whom  the Software  is
# furnished to do so, subject to the following conditions:
#
#        The above copyright notice and this permission notice shall be
#        included in all copies or substantial portions of the Software.
#
# THE SOFTWARE  IS PROVIDED "AS IS",  WITHOUT WARRANTY OF ANY  KIND, EXPRESS OR
# IMPLIED,  INCLUDING BUT  NOT LIMITED  TO THE  WARRANTIES OF  MERCHANTABILITY,
# FITNESS FOR A  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO  EVENT SHALL THE
# AUTHORS  OR COPYRIGHT  HOLDERS  BE LIABLE  FOR ANY  CLAIM,  DAMAGES OR  OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'rubygems'
require 'bundler/setup'
require 'rack'
require 'slop'
require_relative '../space_observatory'
require_relative 'rack_middleware'

class SpaceObservatory::BaseStation < SpaceObservatory::RackMiddleware
  # Fork a base station process
  # @param  [Array]  argv     The ::ARGV
  # @return [IO, IO, Integer, Array]  child's socket, pid, and argv.
  def self.rackup! argv
    _, a    = parse argv
    path    = File.expand_path __FILE__
    cmdline = %W"-r #{path} -e SpaceObservatory::BaseStation.construct --"
    i, o, t = Open3.popen2 %w'ruby ruby', *cmdline, *argv
    return i, o, t.pid, a
  end

  # Child process entry point
  def self.construct
    obj = new ARGV, STDIN, STDOUT
    if obj.need_rackup?
      obj.rackup
    else
      obj.banner
    end
  end

  # Parse command line
  # @param [Array] argv argv
  # @return [Slop, Array] parsed command line parameters, and remains.
  def self.parse argv
    argw = argv.dup
    opts = Slop.parse! argw do
      on 'h', 'help', 'this message'
      on 'port=', 'JSONRPC port', as: Integer
      on 'ttl=', 'cache expiration (in seconds)', as: Float
    end
    return opts, argw
  end

  # @param [Array] argv   the ::ARGV
  # @param [IO]    stdin  the ::STDIN
  # @param [IO]    stdout the ::STDOUT
  def initialize argv, stdin, stdout
    @argv        = argv
    @stdin       = stdin
    @stdout      = stdout
    @stdout.sync = true # we need line IO
    @opts, @argw = self.class.parse argv
    @argw.shift if @argw.first == '--'

    super nil, '/', @opts['ttl'] || 60 # 300 # 3600
  end

  def rackup
    Rack::Handler::WEBrick.run self, Port: @opts['port']
  end

  def need_rackup?
    not @opts['h'] and not @argw.empty?
  end

  def banner
    @stdout.puts "space_observatory norun"
    @stdout.puts @opts.help if @opts['h']
    @stdout.flush
    @stdout.close_write
  end

  private

  def start_collector
    retun unless need_rackup?

    Thread.start do
      loop do
        env = @queue.deq # block here
        @mutex.synchronize do
          next if Time.now - @started < @expires
          @stdout.puts "space_observatory probe"
        end
      end
    end

    Thread.start do
      # needs handshale
      @stdout.puts "space_observatory ok"
      @stdin.gets # wait execve(2)
      @stdout.puts "space_observatory setup"

      tmp = Tempfile.new ''
      while line = @stdin.gets
        case line
        when "space_observatory projectile_eof\n"
          Rack::Handler::WEBrick.shutdown rescue nil
          @stdout.close
          return
        when "space_observatory begin_objspace\n"
          @started = Time.now
          @mutex.lock
          tmp.truncate 0
        when "space_observatory end_objspace\n"
          cook tmp
          @mutex.unlock
          @finished = Time.now
          STDERR.printf "took %fsec\n", (@finished - @started).to_f
        when /\A{/o
          # This is the output of ObjectSpace.dump_all
          tmp.write line
        else
		raise "TBW: #{line}"
        end
      end
    end
  end
end
