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
require "castoro-gateway"

require "logger"
require "fileutils"
require "socket"
require "monitor"
require "sync"
require "stringio"

module Castoro
  class ServerError < CastoroError; end

  class Gateway

    class ConsoleServer
      include WorkersHelper

      @@forker = Proc.new { |server_socket, client_socket, &block|
        Process.detach fork {
          server_socket.close
          block.call client_socket
        }
      }

      DEFAULT_SETTINGS = {
        :accept_expire => 0.5,
        :get_expire    => 10.0,
        :host          => nil,
        :name          => "tcp server",
      }

      ##
      # initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +repository+::
      #   the repository instance.
      # +port+::
      #   port number of TCP Socket.
      # +options+::
      #   server options.
      #
      # Valid options for +options+ are:
      #
      #   [:accept_expire]    timeout second of accept.
      #   [:get_expire]       timeout second of get.
      #   [:host]             allow hosts.
      #   [:name]             default is "unix server". symbol of component.
      #                       It is used for exception message and log message.
      #
      def initialize logger, repository, port, options = {}
        raise ServerError, "zero and negative number cannot be set to port." if port.to_i <= 0

        @logger     = logger || Logger.new(nil)
        @repository = repository
        @port       = port.to_i

        options.reject! { |k, v| !(DEFAULT_SETTINGS.keys.include? k.to_sym)}
        DEFAULT_SETTINGS.merge(options).each { |k, v|
          instance_variable_set "@#{k}", v
        }

        @locker        = Sync.new
        @accept_locker = Monitor.new
      end

      ##
      # start tcp server.
      #
      def start
        @locker.synchronize(:EX) {
          raise ServerError, "#{@name} already started." if alive?

          @accept_locker.synchronize {
            @tcp_server = TCPServer.new(@host, @port)
          }

          @thread = Thread.fork {
            begin
              accept_loop
            rescue => e
              print "#{e.class} #{e.message} #{e.backtrace.join("\n")}"
              Thread.exit
            end
          }

          self
        }
      end

      ##
      # stop tcp server.
      #
      def stop
        @locker.synchronize(:EX) {
          raise ServerError, "#{@name} already stopped." unless alive?

          @thread[:dying] = true

          @accept_locker.synchronize {
            @tcp_server.close
            @tcp_server = nil
          }

          @thread.join
          @thread = nil

          self
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?
        @locker.synchronize(:SH) {
          @tcp_server && !@tcp_server.closed? && @thread
        }
      end

      private

      ##
      # accept loop.
      #
      # When socket received, It evaluates the command in forked process.
      #
      # end conditions.
      # * When true is given to Thread.current[:dying]
      # * When you execute #stop
      #
      def accept_loop

        until Thread.current[:dying]
          begin
            accept { |socket|

              if IO.select([socket], nil, nil, @get_expire)
                accept_command(socket, socket.gets) { |cmd|
                  case cmd
                  when Protocol::Command::Status
                    res = Protocol::Response::Status.new(nil, @repository.status)
                    send_response(socket, res)
      
                  when Protocol::Command::Dump
                    @@forker.call(@tcp_server, socket) { |sock|
                      @repository.dump sock
                    }
      
                  else
                    raise GatewayError, "only Status, Dump and Nop are acceptable."
                  end
                }
              end

            }
          rescue => e
            @logger.error { e.message }
            @logger.debug { e.backtrace.join("\n\t") }
            raise
          end
        end

      end

      def accept
        accepted = @accept_locker.synchronize {
          return nil unless @tcp_server
          return nil unless IO.select([@tcp_server], nil, nil, @accept_expire)
          @tcp_server.accept
        } 

        if accepted
          begin
            yield accepted
          ensure
            accepted.close
          end
        end
      end
    end
  end
end
