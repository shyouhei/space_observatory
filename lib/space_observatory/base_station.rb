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

require 'socket'
require 'rack'
require 'slop'
require_relative '../space_observatory'

class SpaceObservatory::BaseStation
  # Fork a base station process
  # @param  [Array]  argv     The ::ARGV
  # @return [Socket, Integer, Array]  child's socket, pid, and argv.
  def self.rackup! argv
    # FIXME: should falllback to AF_INET for non-unix
    parent, child = Socket.pair :UNIX, :STREAM # SOCK_STREAM intentional.
    slop, argw    = parse ARGV
    path          = File.expand_path __FILE__
    cmdline       = %W"-r #{path} -e SpaceObservatory::BaseStation.new(7).rackup"
    packed        = Marshal.dump argv
    pid           = Process.spawn ['ruby', 'ruby'], *cmdline, {
      0             => :close,
      7             => child,
      :close_others => true,
    }
    parent.puts packed.length
    parent.write packed
    return parent, pid, argw
  end

  # Parse command line
  # @param [Array] argv argv
  # @return [Slop, Array] parsed command line parameters, and remains.
  def self.parse argv
    argw = argv.dup
    opts = Slop.parse! argw do
      on 'h', 'help', 'this message'
    end
    return opts, argw
  end

  # @param [Integer] fileno where to read
  def initialize fileno
    @socket      = IO.for_fd fileno, 'r+b:binary:binary'
    length       = @socket.gets.to_i
    argstr       = @socket.read length
    @argv        = Marshal.load argstr
    @opts, @argw = self.class.parse @argv
    @argw.shift if @argw.first == '--'
  end

  def rackup
    if norun?
      @socket.puts "space_observatory norun"
      @socket.puts @opts.help if @opts['h']
      @socket.flush
      @socket.close_write
    else
      @socket.puts "space_observatory ok"
      @socket.flush
      @socket.gets # wait execve(2)
      @socket.puts "space_observatory setup"
      @socket.puts "space_observatory probe"
      while line = @socket.gets
        case line
        when 'fin'
          return
        when /^start/
        when /^end/
        else
		raise 'TBW'
        end
      end
    end
  end

  private
  def norun?
    @opts['h'] or @argw.empty?
  end
end
