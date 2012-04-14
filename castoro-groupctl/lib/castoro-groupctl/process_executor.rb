#
#   Copyright 2010 Ricoh Company, Ltd.
#
#   This file is part of Castoro.
#
#   Castoro is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Lesser General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Castoro is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public License
#   along with Castoro.  If not, see <http://www.gnu.org/licenses/>.
#

require 'thread'

module Castoro
  module Peer

    class ProcessExecutor
      attr_reader :pid

      def execute *command
        r0, @w0 = IO::pipe
        @r1, w1 = IO::pipe
        @r2, w2 = IO::pipe

        @pid = Process.fork
        if @pid  # in a parent process
          r0.close
          w1.close
          w2.close
        else     # in a child process
          @w0.close
          @r1.close
          @r2.close
          exec( *command, STDIN => r0, STDOUT => w1, STDERR => w2 )
        end
      end

      def gets
        t1, stdout = gets_from @r1
        t2, stderr = gets_from @r2
        t1.join
        t2.join
        [ stdout, stderr ]
      end

      def puts_and_gets stdin
        t0 = puts_to @w0, stdin
        stdout, stderr = gets
        t0.join
        [ stdout, stderr ]
      end

      def wait
        pid, status = Process.waitpid2 @pid
        status.exitstatus
      end

      private

      def puts_to fd, data
        tid = Thread.new do
          data.each do |s|
            fd.puts s
          end
          fd.close
        end
        tid
      end

      def gets_from fd
        data = []
        tid = Thread.new do
          until fd.eof? do
            s = fd.gets
            data.push s
          end
          fd.close
        end
        [ tid, data ]
      end
    end

  end
end
