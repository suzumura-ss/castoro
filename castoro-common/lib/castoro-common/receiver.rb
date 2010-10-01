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

require "castoro-common"

require "logger"
require "socket"
require "ipaddr"
require "thread"
require "timeout"

module Castoro
  module Receiver
    class ReceiverError < CastoroError; end

    ##
    # TCP asynchronization receiver.
    #
    class TCP

      SELECT_EXPIRE = 0.5

      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +port+::
      #   listen port.
      # +thread_count+::
      #   count of worker threads. (default 1)
      # +subscriber+::
      #   When the packet is received, the block is evaluated.
      #
      def initialize logger, port, thread_count = 1, &subscriber
        raise ReceiverError, "zero and negative number cannot be set to port." if port.to_i <= 0

        @logger       = logger || Logger.new(nil)
        @port         = port.to_i
        @thread_count = thread_count.to_i <= 0 ? 1 : thread_count.to_i
        @subscriber   = subscriber || Proc.new { |command|
          command.error_response :message => "not implemented."
        }

        @locker       = Mutex.new
        @sock_locker  = Mutex.new
      end

      ##
      # Start receiver service.
      #
      def start
        @locker.synchronize {
          raise ReceiverError, "receiver service already started." if alive?
          @tcp_server = TCPServer.new(@port)

          @threads = (1..@thread_count).map {
            Thread.fork {
              ThreadGroup::Default.add Thread.self
              listen_loop
            }
          }
        }
      end

      ##
      # Stop receiver service.
      #
      # === Args
      # 
      # +stop+::
      #   When true, force shutdown.
      #
      def stop force = false
        @locker.synchronize {
          raise ReceiverError, "receiver service already stopped." unless alive?
          @threads.each { |t| t[:dying] = true }
          @threads.each { |t| t.wakeup rescue nil }
          @threads.each { |t| t.join }
          @threads = nil

          @tcp_server.close
        }
      end

      ##
      # Return the state of alive or not alive.
      #
      def alive?; !!@threads and !!@tcp_server; end

      private

      def listen_loop
        until Thread.current[:dying]
          accept { |data|
            begin
              cmd = Protocol.parse(data)

              begin
                res = @subscriber.call(cmd)
                raise ReceiverError, "the response is undefined." unless res
                res

              rescue => e
                cmd.error_response "code" => e.class.to_s, "message" => e.message
              end

            rescue
              Protocol::Response.new "message" => "unknown data format."
            end
          }
        end
      end

      def accept
        c = @sock_locker.synchronize {
          return nil if Thread.current[:dying]

          if (res = IO.select([@tcp_server], nil, nil, SELECT_EXPIRE))
            sock = res[0][0]
            sock.accept
          end
        }

        if c
          begin
            while (data = c.gets)
              c.write yield(data).to_s
            end
          ensure
            c.close rescue nil
          end
        end
      end

    end

    ##
    # The Intelletual UDP asynchronization receiver.
    #
    class UDP
      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +port+::
      #   number of receive port.
      # +&subscriber+::
      #   When the packet is received, the block is evaluated.
      #
      # === Example
      #
      # <pre>
      # require "logger"
      # require "rubygems"
      # require "castoro-utils"
      # require "castoro-utils/receiver"
      #
      # l = Logger.new(STDOUT)
      # r = Castoro::Receiver::UDP.new(l, 12345) { |header, data, port, ip|
      #
      #   # header  Castoro::Protocol::UDPHeader
      #   # data    Castoro::Protocol (inhirit classes.)
      #   # port    Fixnum
      #   # ip      String
      #
      #   # when the packet is received, it reaches this line.
      #   l.info { "received from #{ip}:#{port}\r\n#{header}#{data}" }
      #
      # }
      # 
      # # When SIGINT signal reception, stop Receiver service.
      # Signal.trap(:SIGINT) { r.stop }
      #
      # r.start  # The reception of 12345 ports begins.
      # while r.alive?; sleep 3; end
      # </pre>
      #
      def initialize logger, port, &subscriber
        raise ReceiverError, "zero and negative number cannot be set to port." if port.to_i <= 0

        @logger     = logger || Logger.new(nil)
        @port       = port
        @subscriber = subscriber || Proc.new { |data, port, ip| nil }
        
        @locker     = Mutex.new
      end

      ##
      # Start receiver service.
      #
      def start
        @locker.synchronize {
          raise ReceiverError, "#{@port}/receiver already started." if alive?

          @socket = UDPSocket.open
          @socket.bind("0.0.0.0", @port)
          set_sock_opt @socket

          @thread = Thread.fork {
            ThreadGroup::Default.add Thread.current
            listen_loop
          }
        }
      end

      ##
      # Stop receiver service.
      #
      def stop force = false
        @locker.synchronize {
          raise ReceiverError, "#{@port}/receiver already stopped." unless alive?

          if force
            @thread.kill
          else
            @thread[:dying] = true
            @thread.join
          end
          unset_sock_opt @socket
          @socket.close
          @socket = nil
          @thread = nil
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?; !!@thread; end

    private

      def listen_loop
        until Thread.current[:dying]
          if (res = IO::select([@socket], nil, nil, 1))
            sock = res[0][0]
            begin
              data, sockaddr = sock.recvfrom(1024)
              port, ip = sockaddr[1].to_i, sockaddr[3].to_s
            rescue Errno::ECONNRESET => e
              @logger.error { e.message }
              @logger.debug { e.backtrace.join("\n\t") }
              next
            end
            @logger.debug { "#{@port} / received data from #{ip}:#{port}\r\n#{data}" }

            # call subscriber proc.
            begin
              lines = data.split("\r\n")

              # parse header and data.
              header = Protocol::UDPHeader.parse(lines[0])
              data = Protocol.parse(lines[1])

              @subscriber.call(header, data, port, ip)

            rescue => e
              @logger.error { e.message }
              @logger.debug { e.backtrace.join("\n\t") }
              next
            end
          end
        end
      end

      ##
      # When the socket begins,
      # the option can be set by changing the definition of the method.
      #
      def set_sock_opt socket; end

      ##
      # When the socket ends,
      # the option can be set by changing the definition of the method.
      #
      def unset_sock_opt socket; end
    end

    ##
    # Class of multicast setting to Castoro::Receiver::UDP
    #
    class UDP::Multicast < UDP
      ##
      # Initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +port+::
      #   number of receive port.
      # +multicast_addr+::
      #   multicast receive address.
      # +device_addr+::
      #   multicast receive network interface device address.
      # +&subscriber+::
      #   When the packet is received, the block is evaluated.
      #
      def initialize logger, port, multicast_addr, device_addr
        super(logger, port)
        @mreq = IPAddr.new(multicast_addr).hton + IPAddr.new(device_addr).hton
      end

    private

      def set_sock_opt socket
        socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, @mreq)
        socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)
      end

      def unset_sock_opt socket
        socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, @mreq)
      end
    end
  end
end
