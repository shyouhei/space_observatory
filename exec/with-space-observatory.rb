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

# This file is  ultra tricky because it  can be both executed as  a script, AND
# required as  a library.  PLUS, when  required, it shall not  leak any objects
# because that should affect its probing result.
#
#     The cause of  this evilness is that we cannot  assume our helper routines
#     are on  the load path.   So the  only safe way  is to require  this exact
#     file.

if __FILE__ == $0
  # This case we are  executed as a script (first stage).   Our mission here is
  # to spawn  a process  that acts  as JSONRPC server,  then exec  the original
  # projectile, with injecting  a file descriptor that connects  to the spawned
  # server.

  # SIGINT shall interrupt us properly.
  Signal.trap "INT" do
    Process.exit false # false indicates failure.
  end

  require 'rubygems'
  require 'space_observatory/base_station'

  fd, pid, argw = SpaceObservatory::BaseStation.rackup! ARGV

  # Wait for spawned process to parse ARGV...

  case line = fd.gets
  when "space_observatory ok\n" then
    # Normal.  Propel second stage.
    path = File.expand_path __FILE__
    argh = { 7 => fd } # FDs <= 6 happen to be reserved somehow in ruby.
    arge = {
      'RUBYOPT'  => (ENV['RUBYOPT'] || '') + " -r #{path}",
      'BASE_PID' => pid.to_s,
    }
    Process.exec arge, *argw, argh
    # /* NOTREACHED */

  when "space_observatory norun\n" then
    # No need to run, or no runnable projectile specified
    STDOUT.write fd.read # dump if any
    Process.exit true

  else
    # Something went wrong
    STDOUT.puts line
    STDOUT.puts fd.read # dump if any
    Process.exit false
  end

else
  # We  are `require`d  here  (second  stage).  This  case  we  SNEAK INTO  the
  # projectile.  So to minimize the impact  of our presence, we require nothing
  # but `objspace.so`.

  begin
    # File descriptor number 7 should have been passed (see 1st stage).
    ctrl = IO.for_fd 7, 'r+b:binary:binary'
    th   = Thread.start ctrl do |io|
      begin
        ctrl.puts 'hello' # notify end of execve(2)
        loop do
          # This is the key part of this entire lib.
          case io.gets
          when "space_observatory setup\n" then
            require 'objspace'
          when "space_observatory probe\n" then
            io.puts 'start'
            ObjectSpace.dump_all output: io
            io.puts 'end'
          when "space_observatory teardown\n", NilClass then
            Thread.exit
          end
        end
      rescue Errno::EPIPE
        # Abnormal end of peer
      end
    end
    at_exit do
      ctrl.puts 'fin'
      ctrl.close_write
      Process.waitpid ENV['BASE_PID'].to_i if ENV['BASE_PID']
      th.join
    end
  rescue Errno::EBADF, Errno::EINVAL
    # Maybe a grand-child process.  Just leave nothing.
  end
end
