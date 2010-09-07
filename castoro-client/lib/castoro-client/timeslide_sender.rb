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

require "castoro-client"

require "logger"
require "monitor"
require "timeout"
require "yaml"

module Castoro
  class Client

    ##
    # Sender of Timeslide Multicast.
    #
    # It is a class that has the function to transmit doing 
    # the slide for destinations until the response is received. 
    #
    class TimeslideSender

      attr_reader :sid, :port

      ##
      # initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +my_host+::
      #   Host name that can be recognized from other hosts.
      # +my_ports+::
      #   Range of UDP port number that can be secured.
      # +destinations+::
      #   Array of character string that shows destination address (and port)
      # +expire+::
      #   response timeout (second).
      # +request_interval+::
      #   Interval when packet is transmitted to the next host.
      #
      # destinations format sample:
      # 
      # <pre>
      # [ "example.com:30111", "foo.bar.baz:30112", "hoge.fuga:30113" ]
      # </pre>
      #
      def initialize logger, my_host, my_ports, destinations, expire, request_interval

        raise ClientError, "invalid setting value \"my_host\" => (#{my_host})" unless host_or_ip? my_host
        raise ClientError, "null array cannot be set to my_ports" if my_ports.empty?
        case destinations
        when Array, String
          #
        else
          raise ClientError, "destinations cannot be set excluding Array or String."
        end
        destinations = destinations.to_a if destinations.kind_of?(String)
        destinations.to_a.map! { |d| d.to_s }
        raise ClientError, "Illegal destination format." unless destinations.all? { |d| d =~ /^.+:\d+$/ }

        raise ClientError, "it is necessary to set the numerical value to expire" if expire.to_f == 0.0
        if request_interval.to_f == 0.0
          raise ClientError, "it is necessary to set the numerical value to request_interval"
        end

        @logger           = logger || Logger.new(nil)
        @my_host          = my_host
        @my_ports         = my_ports
        @destinations     = destinations.to_a.sort_by{ rand }
        @expire           = expire.to_f
        @request_interval = request_interval.to_f

        @locker           = Monitor.new
        @response_locker  = Monitor.new
        @response_queue   = []

        @sid = 0
      end

      ##
      # start sender.
      #
      def start
        @locker.synchronize {
          raise ClientError, "timeslide sender already started." if alive?

          @sender = Sender::UDP.new @logger
          @sender.start

          @port = nil
          @my_ports.sort_by { rand }.each { |p|
            begin
              @receiver = Receiver::UDP.new(@logger, p) { |header, data, port, ip|
                push [header, data] if @sid == header.sid
              }
              @receiver.start
              @port = p
              break
            rescue; end
          }
          unless @port
            raise ClientError, "Port was not able to be opened according to the specified array."
          end

          @logger.info { "reserved_port => #{@port}" }

          # pid where start was executed is saved.
          # when PID is changed by the reason such as fork, restart is done.
          @start_pid = Process.pid
        }
      end

      ##
      # stop sender.
      #
      def stop
        @locker.synchronize {
          raise ClientError, "timeslide sender already stopped." unless alive?

          @sender.stop
          @sender = nil
          @receiver.stop
          @receiver = nil
          @port = nil
        }
      end

      ##
      # (re)start sender.
      #
      def restart
        @locker.synchronize {
          stop if alive?
          start
        }
      end

      ##
      # Return the state of alive or not alive.
      #
      def alive?
        @locker.synchronize {
          !! (@sender and @sender.alive? and @receiver and @receiver.alive?)
        }
      end

      ##
      # Send command and get response.
      #
      # +command+::
      #   the request command.
      #
      def send command
        @locker.synchronize {

          raise ClientError, "timeslide sender is not started." unless alive?

          # when PID is changed by the reason such as fork, restart is done.
          restart if @start_pid != Process.pid

          @sid += 1
          clear
          cycle_destinations

          header = Protocol::UDPHeader.new(@my_host, @port, @sid)

          timeslide_multicast(header, command) {
            begin
              result = timeout(@expire) {
                sid = nil
                until @sid == sid
                  if (popped = pop)
                    h, r = popped
                    sid = h.sid rescue nil
                  end
                end
                r
              }
              @logger.debug { "parsed received data\n#{result.to_yaml}" }
              result

            rescue TimeoutError
              @logger.error { "request time out - [#{@sid}]" }
              raise ClientTimeoutError, "request time out."
            end
          }
        }
      end

      private

      ##
      # It transmits doing the slide for destinations until the response is received.
      #
      # === Args
      #
      # +header+::
      #   UDP packet header.
      # +command+::
      #   transmitted command. 
      #
      def timeslide_multicast header, command
        req_thread = Thread.fork {
          interval = 0.0
          @destinations.each { |d|
            host, port = d.split(":")
            @sender.send header, command, host, port
            interval += @request_interval
            sleep interval
            break if Thread.current[:dying]
          }
        }

        begin
          yield
        ensure
          req_thread[:dying] = true
          req_thread.wakeup rescue nil
          req_thread.join
        end
      end

      ##
      # push response to response queue.
      #
      def push value
        @response_locker.synchronize {
          @response_queue << value
        }
      end

      ##
      # popped response from response queue.
      #
      def pop
        @response_locker.synchronize {
          @response_queue.shift
        }
      end

      ##
      # response_queue is cleared.
      #
      def clear
        @response_locker.synchronize {
          @response_queue.clear
        }
      end

      ##
      # The array that shows destination is cycled.
      #
      def cycle_destinations
        @destinations << @destinations.shift       
      end        

      ##
      # The value in which whether correctness as hostname or ipaddress is shown is returned. 
      # 
      # === Args
      #
      # +host+::
      #   name of host.
      #
      def host_or_ip? host
        host =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/ or
        host =~ /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$/
      end

    end

  end
end

