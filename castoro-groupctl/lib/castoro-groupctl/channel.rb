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

require "json"
require 'castoro-groupctl/errors'

module Castoro
  module Peer

    PROTOCOL_VERSION = '1.1'

    class Channel
      def initialize socket
        @socket = socket
        @command = nil
      end

      def parse body, direction_code, exception
        if body.nil? or body == ''
          return [ nil, nil ]
        end
        version, direction, command, args = JSON.parse body
        @command = command  # @command will be used in a response whatever exception occurs
        command.nil? and raise exception, "Command part is nil: #{body}"
        version == PROTOCOL_VERSION or raise exception, "Version #{PROTOCOL_VERSION} is expected: #{version}: #{body}"
        direction == direction_code or raise exception, "Direction #{direction_code} is expected: #{direction}: #{body}"
        [ command, args ]
      end
    end


    class ServerChannel < Channel
      def parse body
        super body, 'C', BadRequestError
      end

      def send_response result
        if result.is_a? Exception
          args = { :error => { 
              :code => result.class, 
              :message => result.message,
              :backtrace => result.backtrace.slice(0,5) } }
        else
          args = result
        end
        [ PROTOCOL_VERSION, 'R', @command, args ].to_json
      end
    end


    class TcpServerChannel < ServerChannel
      def receive_command
        data = @socket.gets
        parse data
      rescue EOFError => e
        [ nil, nil ]
      end

      def send_response result
        @socket.syswrite "#{super}\r\n"
      end
    end


    class UdpServerChannel < ServerChannel
      def receive_command
        data = @socket.receiving
        @header, body = data.split "\r\n"
        @addr, @port, @session = JSON.parse @header
        parse body
      end

      def send_response result
        @socket.sending "#{@header}\r\n#{super}\r\n", @addr, @port
      end
    end


    class ClientChannel < Channel
      def send_command command, args
        @command = command
        [ PROTOCOL_VERSION, 'C', command, args ].to_json
      end

      def parse body
        command, args = super body, 'R', BadResponseError
        @command == command or raise BadResponseError, "Command #{@command} is expected: #{command}: #{body}"
        [ command, args ]
      end
    end


    class TcpClientChannel < ClientChannel
      def send_command command, args
        @socket.syswrite "#{super}\r\n"
      end

      def receive_response
        data = @socket.gets
        parse data
      end
    end


    class UdpClientChannel < ClientChannel
      def send_command command, args, addr, port
        session = SessionIdGenerator.instance.generate
        # Todo: peer does not expect any response from a receipient
        header = [ '0.0.0.0', 0, session ].to_json  # reply address, reply port, session id
        body   = super command, args
        @socket.sending "#{header}\r\n#{body}\r\n", addr, port
      end

      def receive_response
        # Todo: do we need to implement this?
      end
    end

  end
end

__END__
