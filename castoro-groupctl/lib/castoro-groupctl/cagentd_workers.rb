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

require 'castoro-groupctl/pre_threaded_tcp_server'
require 'castoro-groupctl//tcp_socket'
require 'castoro-groupctl/channel'
require 'castoro-groupctl/configurations'
require 'castoro-groupctl/log'

module Castoro
  module Peer

    class CagentdWorkers
      def initialize
        @server = CagentdTcpServer.new
      end

      def start
        @server.start
      end

      def stop
        @server.stop
      end
    end


    class CagentdTcpServer < PreThreadedTcpServer
      def initialize
        port = Configurations.instance.cagentd_comm_tcpport
        addr = '0.0.0.0'
        number_of_threads = 5
        super port, addr, number_of_threads
      end

      def serve socket
        loop do
          return if socket.closed?
          s = TcpSocketDelegator.new socket
          serve_impl s
        end
      rescue => e
        Log.err e
        sleep 0.1
      end

      def serve_impl socket
        channel = TcpServerChannel.new socket
        command, args = channel.receive_command
        command.nil? and return 0  # end of file reached
        result = case command.upcase
                 when 'GETPROP'  ; do_getprop args
                 when 'SETPROP'  ; do_setprop args
                 when 'QUIT'     ; socket.close ; return
                 when 'SHUTDOWN' ; CagentdMain.instance.shutdown_requested ; return
                 else
                   raise BadRequestError, "Unknown command: #{command}"
                 end
        channel.send_response result

      rescue => e
        channel.send_response e
      end

      def do_get_set_prop args, value
        target = args[ 'target' ] or raise ArgumentError, "taget is not specified: #{args.inspect}"
        port = case target
               when 'cmond'         ; Configurations.instance.cmond_maintenance_tcpport
               when 'cpeerd'        ; Configurations.instance.cpeerd_maintenance_tcpport
               when 'crepd'         ; Configurations.instance.crepd_maintenance_tcpport
               when 'cmanipulatord'
                 raise ArgumentError, "cmanipulatord has no control port."
               else
                 raise ArgumentError, "Unknown target: #{target}"
               end

        name = args[ 'name' ] or raise ArgumentError, "name is not specified: #{args.inspect}"
        command = case name
                  when 'mode'  ; 'mode'
                  when 'auto'  ; 'auto'
                  when 'debug' ; 'debug'
                  else
                    raise ArgumentError, "Unknown name: #{name}"
                  end
        command = "#{command} #{value}" if value

        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        { :target => target, :name => name, :value => value }
      end

      def do_getprop args
        do_get_set_prop args, nil
      end

      def do_setprop args
        value = args[ 'value' ] or raise ArgumentError, "value is not specified: #{args.inspect}"
        do_get_set_prop args, value
      end
    end

  end
end
