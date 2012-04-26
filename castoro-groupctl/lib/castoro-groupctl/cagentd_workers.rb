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
          r = serve_impl s 
          return if r == :closed
          sleep 0.01
        end
      rescue => e
        Log.err e
        sleep 0.1
      end

      def serve_impl socket
        channel = TcpServerChannel.new socket
        command, args = channel.receive_command
        command.nil? and return :closed  # end of file reached
        result = case command.upcase
                 when 'GETPROP'  ; do_getprop args
                 when 'SETPROP'  ; do_setprop args
                 when 'STATUS'   ; do_status args
                 when 'MODE'     ; do_mode args
                 when 'AUTO'     ; do_auto args
                 when 'QUIT'     ; socket.close ; return :closed
                 when 'SHUTDOWN' ; do_shutdown ; return :closed
                 else
                   raise BadRequestError, "Unknown command: #{command}"
                 end
        channel.send_response result

      rescue => e
        channel.send_response e
      end

      def do_shutdown
        # something goes wrong with Ruby 1.9.2 running on CentOS 6.2
        # so, do it in another thread
        Thread.new do
          CagentdMain.instance.shutdown_requested
        end
      end

      def do_get_set_prop args, value
        target = args[ 'target' ] or raise ArgumentError, "taget is not specified: #{args.inspect}"
        port = case target
               when 'cmond'         ; Configurations.instance.cmond_maintenance_tcpport
               when 'cpeerd'        ; Configurations.instance.cpeerd_maintenance_tcpport
               when 'crepd'         ; Configurations.instance.crepd_maintenance_tcpport
               when 'manipulatord'
                 raise ArgumentError, "manipulatord has no control port."
               else
                 raise ArgumentError, "Unknown target: #{target}"
               end

        name = args[ 'name' ] or raise ArgumentError, "name is not specified: #{args.inspect}"
        command = case name
                  when 'mode'
                    value = value.to_s if value
                    'mode'
                  when 'auto'
                    value = value ? 'auto' : 'off' if value
                    'auto'
                  when 'debug'
                    value = value ? 'on' : 'off' if value
                    'debug'
                  else
                    raise ArgumentError, "Unknown name: #{name}"
                  end
        command = "#{command} #{value}" if value

        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close

        value = case name
                when 'mode'
                  value.match( /mode: *([0-9]+)/ )[1].to_i
                when 'auto'
                  x = value.match( /auto: *(auto)?(off)?/ )
                  x[1] ? true : ( x[2] ? false : nil )
                when 'debug'
                  x = value.match( /mode: *(on)?(off)?/ )
                  x[1] ? true : ( x[2] ? false : nil )
                end
        { :target => target, :name => name, :value => value }
      end

      def do_getprop args
        do_get_set_prop args, nil
      end

      def do_setprop args
        value = args[ 'value' ] or raise ArgumentError, "value is not specified: #{args.inspect}"
        do_get_set_prop args, value
      end

      def do_status args
        target = args[ 'target' ] or raise ArgumentError, "taget is not specified: #{args.inspect}"
        port = case target
               when 'cmond'         ; Configurations.instance.cmond_maintenance_tcpport
               when 'cpeerd'        ; Configurations.instance.cpeerd_maintenance_tcpport
               when 'crepd'         ; Configurations.instance.crepd_maintenance_tcpport
               when 'manipulatord'
                 raise ArgumentError, "manipulatord has no control port."
               else
                 raise ArgumentError, "Unknown target: #{target}"
               end

        command = 'mode'
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        mode = value.match( /mode: *([0-9]+)/ )[1].to_i

        command = 'auto'
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        x = value.match( /auto: *(auto)?(off)?/ )
        auto = x[1] ? true : ( x[2] ? false : nil )

        command = 'debug'
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        x = value.match( /mode: *(on)?(off)?/ )
        debug = x[1] ? true : ( x[2] ? false : nil )

        { :target => target, :mode => mode, :auto => auto, :debug => debug }
      end

      def do_mode args
        target = args[ 'target' ] or raise ArgumentError, "taget is not specified: #{args.inspect}"
        port = case target
               when 'cmond'         ; Configurations.instance.cmond_maintenance_tcpport
               when 'cpeerd'        ; Configurations.instance.cpeerd_maintenance_tcpport
               when 'crepd'         ; Configurations.instance.crepd_maintenance_tcpport
               when 'manipulatord'
                 raise ArgumentError, "manipulatord has no control port."
               else
                 raise ArgumentError, "Unknown target: #{target}"
               end

        mode = args[ 'mode' ] or raise ArgumentError, "mode is not specified: #{args.inspect}"
        x = mode.to_s

        command = "mode"
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        mode_previous = value.match( /mode: *([0-9]+)/ )[1].to_i

        command = "mode #{x}"
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        mode = value.match( /mode: *([0-9]+)/ )[1].to_i

        { :target => target, :mode_previous => mode_previous, :mode => mode }
      end

      def do_auto args
        target = args[ 'target' ] or raise ArgumentError, "taget is not specified: #{args.inspect}"
        port = case target
               when 'cmond'         ; Configurations.instance.cmond_maintenance_tcpport
               when 'cpeerd'        ; Configurations.instance.cpeerd_maintenance_tcpport
               when 'crepd'         ; Configurations.instance.crepd_maintenance_tcpport
               when 'manipulatord'
                 raise ArgumentError, "manipulatord has no control port."
               else
                 raise ArgumentError, "Unknown target: #{target}"
               end

        args.has_key? 'auto' or raise ArgumentError, "auto is not specified: #{args.inspect}"
        auto = args[ 'auto' ] ? 'auto' : 'off'

        command = "auto"
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        x = value.match( /auto: *(auto)?(off)?/ )
        auto_previous = x[1] ? true : ( x[2] ? false : nil )

        command = "auto #{auto}"
        client = TcpClient.new
        socket = client.timed_connect '127.0.0.1', port, 3
        socket.puts command
        value = socket.timed_gets 3
        socket.close
        x = value.match( /auto: *(auto)?(off)?/ )
        auto = x[1] ? true : ( x[2] ? false : nil )

        { :target => target, :auto_previous => auto_previous, :auto => auto }
      end
    end

  end
end
