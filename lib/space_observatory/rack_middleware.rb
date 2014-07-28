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

require 'objspace'
require 'thread'
require 'tempfile'
require 'open3'
require 'rubygems'
require 'bundler/setup'
require_relative '../space_observatory'

class SpaceObservatory::RackMiddleware

  def initialize app, path = '/space', expires = 60 # 300 # 3600
    @app      = app
    @path     = path
    @expires  = expires
    @mutex    = Mutex.new
    @queue    = Queue.new
    @latest   = nil
    @started  = Time.at 0
    @finished = Time.at 0
    @thread   = start_collector
  end

  def call env
    return @app.call env if @app and env['PATH_INFO'] != @path

    @queue.enq env
    hdr = {
      'Connection'   => 'close',
      'Content-Type' => 'application/json',
      'rack.hijack'  => lambda do |fp|
        Thread.start do
          begin
            Thread.pass until @latest
            @mutex.synchronize do
              @latest.rewind
              IO.copy_stream @latest, fp
            end
          rescue Errno::ENOTCONN
          ensure
            fp.close
          end
        end
      end
    }
    return [ 200, hdr, nil ]
  end

  private
  
  def start_collector
    Thread.start do
      loop do
        env = @queue.deq # block here
        @mutex.synchronize do
          next if Time.now - @started < @expires

          @started = Time.now # prevent further probe
          env['rack.errors'] << "Collection happen at #@started\n"
          tmp1 = ObjectSpace.dump_all output: :file
          cook tmp1
          tmp1.close
          @finished = Time.now
          env['rack.errors'] << "Collection done in #{@finished - @started} secs.\n"
        end
      end
    end
  end

  def cook io
    @latest ||= Tempfile.new ''
    @latest.rewind
    @latest.truncate 0
    @latest.print <<-"end".gsub(/^\s+(\S)/, '\\1').gsub(/[\r\n]/, "\r\n")
      HTTP/1.1 200 OK
      Content-Type: application/json
      Connection: close

    end
    @latest.puts <<-"]".gsub(/^\s+/, '')
      {
        "jsonrpc" : "2.0",
        "id" : #{@started.to_i},
        "result" : [
    ]
    # This subprocessing is CHAPER than gsub-ing ourselves because
    # gsub creates TONS of garbage string objects, which would be
    # counted in the next ObjectSpace.dump_all call.
    #
    # Also note that this can totally be avoided if
    # ObjectSpace.dump_all have generated valid JSON from the outset.
    Open3.pipeline_r "cat #{io.path}", 'sed s/$/,/' do |r,|
      IO.copy_stream r, @latest
    end
    @latest.print "]\n}\n"
  end
end
