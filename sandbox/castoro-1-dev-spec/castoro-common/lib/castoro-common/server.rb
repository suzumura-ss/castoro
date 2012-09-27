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
require "fileutils"
require "socket"
require "thread"

module Castoro
  class ServerError < CastoroError; end

  module Server

    class UNIX

      DEFAULT_SETTINGS = {
        :accept_expire  => 0.5,
        :get_expire     => 1.0,
        :get_try_count  => 10,
        :sock_file_mode => nil,
        :keep_alive     => false,
        :name           => "unix server",
      }

      ##
      # initialize and start (and stop).
      #
      # === Args
      #
      # It applies to #initialize
      #
      # === Example
      #
      # <pre>
      # l = Logger.new(STDOUT)
      # f = "/tmp/server.sock"
      #
      # Castoro::Server::UNIX.start(l, f) { |s|
      #
      #   # s.class => Castoro::Server::UNIX
      #   puts s.alive? # => true
      # 
      # }
      # </pre>
      #
      def self.start logger, sock_file, options = {}
        s = self.new logger, sock_file, options
        s.start
        if block_given?
          begin
            yield s
          ensure
            s.stop
          end
        end
        s
      end

      ##
      # initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +sock_file+::
      #   fullpath of UNIX Socket.
      # +options+::
      #   server options.
      #
      # Valid options for +options+ are:
      #
      #   [:accept_expire]    timeout second of accept.
      #   [:get_expire]       timeout second of get.
      #   [:get_try_count]    count of get trying.
      #                       The value of "get_expire*get_try_count" becomes
      #                       the approximate value of connected timeout.
      #   [:sock_file_mode]   permission of UNIX socket file. The octal number 
      #                       numerical value such as 0775 is specified.
      #   [:keep_alive]       When true, connection of client is maintained.
      #   [:name]             default is "unix server". symbol of component.
      #                       It is used for exception message and log message.
      #
      def initialize logger, sock_file, options = {}
        begin
          FileUtils.touch sock_file
        rescue Errno::EACCES => e
          raise ServerError, e.message
        end

        @logger        = logger || Logger.new(nil)
        @sock_file     = sock_file.to_s

        options.reject! { |k, v| !(DEFAULT_SETTINGS.keys.include? k.to_sym)}
        DEFAULT_SETTINGS.merge(options).each { |k, v|
          instance_variable_set "@#{k}", v
        }

        @locker        = Mutex.new
        @accept_locker = Mutex.new
      end

      ##
      # start unix server.
      #
      def start
        @locker.synchronize {
          raise ServerError, "#{@name} already started." if alive?

          File.unlink @sock_file if File.exist? @sock_file
          @unix_server = UNIXServer.open(@sock_file)
          begin
            FileUtils.chmod @sock_file_mode, @sock_file if @sock_file_mode
          rescue
            @unix_server.close
            @unix_server = nil
            raise
          end
          self
        }
      end

      ##
      # stop unix server.
      #
      def stop
        @locker.synchronize {
          raise ServerError, "#{@name} already stopped." unless alive?

          Thread.current[:dying] = true

          @unix_server.close
          @unix_server = nil
          self
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?; @unix_server and !@unix_server.closed?; end

      ##
      # client loop.
      #
      # When socket received, It keeps evaluating the block.
      #
      # end conditions.
      # * When true is given to Thread.current[:dying]
      # * When you execute #stop
      #
      def client_loop

        raise ServerError, "It is necessary to specify the block argument." unless block_given?
        
        while not Thread.current[:dying] and alive?
          begin
            accept { |sock|

              get_try_count = 0
              while get_try_count < @get_try_count
                break if Thread.current[:dying] or not alive?

                get_try_count += 1
                if IO.select([sock], nil, nil, @get_expire)
                  if (ret = sock.gets)
                    yield sock, ret
                    break unless @keep_alive
                    get_try_count = 0
                  end
                end
              end

            }
          rescue => e
            @logger.error { e.message }
            @logger.debug { e.backtrace.join("\n\t") }
          end
        end

      end

      private

      def accept
        accepted = @accept_locker.synchronize {
          return nil unless alive?
          return nil unless IO.select([@unix_server], nil, nil, @accept_expire)
          @unix_server.accept
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

    class TCP

      DEFAULT_SETTINGS = {
        :accept_expire => 0.5,
        :get_expire    => 1.0,
        :get_try_count => 10,
        :host          => nil,
        :keep_alive    => false,
        :name          => "tcp server",
      }

      ##
      # initialize and start (and stop).
      #
      # === Args
      #
      # It applies to #initialize
      #
      # === Example
      #
      # <pre>
      # l = Logger.new(STDOUT)
      # p = 80
      #
      # Castoro::Server::TCP.start(l, p) { |s|
      #
      #   # s.class => Castoro::Server::TCP
      #   puts s.alive? # => true
      # 
      # }
      # </pre>
      #
      def self.start logger, port, options = {}
        s = self.new logger, port, options
        s.start
        if block_given?
          begin
            yield s
          ensure
            s.stop
          end
        end
        s
      end

      ##
      # initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +port+::
      #   port number of TCP Socket.
      # +options+::
      #   server options.
      #
      # Valid options for +options+ are:
      #
      #   [:accept_expire]    timeout second of accept.
      #   [:get_expire]       timeout second of get.
      #   [:get_try_count]    count of get trying.
      #                       The value of "get_expire*get_try_count" becomes
      #                       the approximate value of connected timeout.
      #   [:host]             allow hosts.
      #   [:keep_alive]       When true, connection of client is maintained.
      #   [:name]             default is "unix server". symbol of component.
      #                       It is used for exception message and log message.
      #
      def initialize logger, port, options = {}
        raise ServerError, "zero and negative number cannot be set to port." if port.to_i <= 0

        @logger        = logger || Logger.new(nil)
        @port          = port.to_i

        options.reject! { |k, v| !(DEFAULT_SETTINGS.keys.include? k.to_sym)}
        DEFAULT_SETTINGS.merge(options).each { |k, v|
          instance_variable_set "@#{k}", v
        }

        @locker        = Mutex.new
        @accept_locker = Mutex.new
      end

      ##
      # start tcp server.
      #
      def start
        @locker.synchronize {
          raise ServerError, "#{@name} already started." if alive?

          @tcp_server = TCPServer.new(@host, @port)
          self
        }
      end

      ##
      # stop tcp server.
      #
      def stop
        @locker.synchronize {
          raise ServerError, "#{@name} already stopped." unless alive?

          Thread.current[:dying] = true

          @tcp_server.close
          @tcp_server = nil
          self
        }
      end

      ##
      # return the state of alive or not alive.
      #
      def alive?; @tcp_server and !@tcp_server.closed?; end

      ##
      # client loop.
      #
      # When socket received, It keeps evaluating the block.
      #
      # end conditions.
      # * When true is given to Thread.current[:dying]
      # * When you execute #stop
      #
      def client_loop

        raise ServerError, "It is necessary to specify the block argument." unless block_given?
        
        while not Thread.current[:dying] and alive?
          begin
            accept { |sock|

              get_try_count = 0
              while get_try_count < @get_try_count
                break if Thread.current[:dying] or not alive?

                get_try_count += 1
                if IO.select([sock], nil, nil, @get_expire)
                  if (ret = sock.gets)
                    yield sock, ret
                    break unless @keep_alive
                    get_try_count = 0
                  end
                end
              end

            }
          rescue => e
            @logger.error { e.message }
            @logger.debug { e.backtrace.join("\n\t") }
          end
        end

      end

      private

      def accept
        accepted = @accept_locker.synchronize {
          return nil unless alive?
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
