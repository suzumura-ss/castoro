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

require 'castoro-groupctl/worker'
require 'castoro-groupctl/tcp_socket'
require 'castoro-groupctl/channel'
require 'castoro-groupctl/log'

module Castoro
  module Peer

    class CstartdWorkers
      def initialize
        @server = CstartdTcpServer.new
      end

      def start
        @server.start
      end

      def stop
        @server.stop
      end
    end


    class CstartdTcpServer < Worker
      def initialize
        port = cstartd_comm_tcpport = 30150
        addr = '0.0.0.0'
        backlog = 5
        @listening_socket = TcpServer.new port, addr, backlog
        super
      end

      def serve
        begin
          connected_socket = @listening_socket.accept
        rescue IOError, Errno::EBADF => e
          # IOError "closed stream"
          # Errno::EBADF "Bad file number"
          if @stop_requested
            @finished = true
            return
          else
            raise e
          end
        end

        # Workaround for http://redmine.ruby-lang.org/issues/show/2371
        Log.stop
        pid = Process.fork  # fork returns a Fixnum
        Log.start_again

        if pid
          # Parent process
          connected_socket.close
          Thread.new( pid ) do |x|  # x should be assigned with a value of pid through by-value rather than by-reference
            x_pid, x_status = Process.waitpid2 x
            Log.debug "Child process #{x_pid} exited with #{x_status.exitstatus}" if $DEBUG
            CstartdMain.instance.shutdown_requested if x_status.exitstatus == 99
          end
        else
          # Child process
          status = 1
          begin
            @listening_socket.close
            cp = CommandProcessor.new connected_socket
            status = cp.process
            connected_socket.close unless connected_socket.closed?
            sleep 0.5
          rescue => e
            Log.warning e
            Process.exit! 1
          end
          Process.exit! status
        end
      end

      def stop
        @stop_requested = true
        @listening_socket.close if @listening_socket
        super
      end
    end


    class CommandProcessor
      @@Commands = {
        'START'    => :START,
        'STOP'     => :STOP,
        'SHUTDOWN' => :SHUTDOWN,
      }

      def initialize socket
        @socket = socket
      end

      def process
        channel = TcpServerChannel.new @socket
        command, args = channel.receive_command
        c = @@Commands[ command.upcase ] or raise BadRequestError, "Unknown command: #{command}"
        status, result = case c
                         when :START    ; do_start args
                         when :STOP     ; do_stop args
                         when :SHUTDOWN ; do_shutdown
                         end
        Log.debug "status=#{status} result=#{result.inspect}" if $DEBUG
        channel.send_response result
        status

      rescue => e
        channel.send_response e
        1
      end

      def do_shutdown
        [ 99, nil ]
      end

      def do_start args
        [ 0, { :stdout => '', :stderr => '' } ]
      end

      def do_stop args
        [ 0, { :stdout => '', :stderr => '' } ]
      end
    end

  end
end
