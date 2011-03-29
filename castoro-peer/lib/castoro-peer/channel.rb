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
require 'castoro-peer/errors'
require 'castoro-peer/ticket'
require 'castoro-peer/session_id'

module Castoro
  module Peer

    PROTOCOL_VERSION = '1.1'

    class ServerChannel
      def initialize
        @command = nil
      end

      def parse( body )
        a = JSON.parse( body )
        version, direction, command, args = a
        @command = command  # @command would be needed for a response whatever exception occurs
        version == PROTOCOL_VERSION or raise BadRequestError, "Version #{PROTOCOL_VERSION} is expected, but version: #{version}: #{body}"
        direction == 'C' or raise BadRequestError, "Direction C is expected, but direction: #{direction}: #{body}"
        # the forth parameter could be nil in the inter-crepd communication, so do not block it
        # args.class == Hash or raise BadRequestError, "The forth parameter is not a Hash: #{args}: #{body}"
        a.size == 4 or raise BadRequestError, "The number of parameters does not equal to 4: #{a.size}: #{body}"
        [ command, args ]
      end

      def send( socket, result, ticket = nil )
        # p [ 'ServerChannel#send', result ]
        if ( result.is_a? Exception )
          [ PROTOCOL_VERSION, 'R', @command, 
            { 'error' => { 'code' => result.class, 'message' => result.message } } ].to_json
        else
          [ PROTOCOL_VERSION, 'R', @command, result ].to_json
        end
      end
    end


    class TcpServerChannel < ServerChannel
      def initialize
        @port, @ip = nil, nil
        super
      end

      def receive( socket, ticket = nil )
        @data = socket.gets
        ticket.mark unless ticket.nil?
        unless ( closed? )
          @port, @ip = nil, nil
          begin
            # @port, @ip = socket.peeraddr[1], socket.peeraddr[3]
            @port, @ip = Socket.unpack_sockaddr_in( socket.getpeername )
          rescue
            # do nothing
          end
        else
          socket.close unless socket.closed?
        end
        if ( $DEBUG )
          unless ( closed? )
            Log.debug( sprintf( "TCP I : %s:%s %s", @ip, @port, @data ) )
          else
            Log.debug( sprintf( "TCP Closed   : %s:%s %s", @ip, @port, 'nil' ) )
          end
        end
      end

      def get_peeraddr
        [ @ip, @port ]
      end

      def closed?
        @data.nil? or @data == ''
      end

      def parse
        super( @data )
      end

      def send( socket, result, ticket = nil )
        # p [ 'TcpServerChannel#send', result ]
        s = "#{super}\r\n"
        # @port, @ip = socket.peeraddr[1], socket.peeraddr[3]
        @port, @ip = Socket.unpack_sockaddr_in( socket.getpeername )
        ticket.mark unless ticket.nil?
        socket.syswrite( s )
        ticket.mark unless ticket.nil?
        if ( $DEBUG )
          Log.debug( sprintf( "TCP O : %s:%s %s", @ip, @port, s ) )
        end
      end

      def tcp?
        true
      end
    end


    class UdpServerChannel < ServerChannel
      def receive( socket, ticket = nil )
        @data = socket.receiving( ticket )
        ticket.mark unless ticket.nil?
      end

      def parse
        @header, body = @data.split("\r\n")
        # p @header
        a = JSON.parse( @header )
        a.size == 3 or raise BadRequestError, "The number of parameters does not equal to 3: #{a.size}: #{@header}"
        @ip, @port, @sid = a
        # Todo: validation on ip, port, sid
        super( body )
      end

      def send( socket, result, ticket = nil )
        socket.sending( "#{@header}\r\n#{super}\r\n", @ip, @port, ticket )
      end

      def tcp?
        false
      end
    end


    class UdpMulticastClientChannel
      def initialize( socket )
        @socket = socket
        @reply_ip = Configurations.instance[ :MulticastIf ]
        @reply_port = 0
      end

      def send( command, args, ip, port )  # Todo: swap parameters
        # p [ 'command', command, 'args', args ]
        sid = SessionIdGenerator.instance.generate
        header = [ @reply_ip, @reply_port, sid ].to_json
        body   = [ PROTOCOL_VERSION, 'C', command, args ].to_json
        @socket.sending( "#{header}\r\n#{body}\r\n", ip, port )  # Todo: ticket
      end
    end


    class ClientChannel
      def initialize
        @command = nil
      end

      def send( socket, command, args )
        @command = command
        [ PROTOCOL_VERSION, 'C', @command, args ].to_json
      end

      def parse( body )
        a = JSON.parse( body )
        version, direction, command, args = a
        version == PROTOCOL_VERSION or raise BadResponseError, "Version #{PROTOCOL_VERSION} is expected, but version: #{version}: #{body}"
        direction == 'R' or raise BadResponseError, "Direction R is expected, but direction: #{direction}: #{body}"
        command == @command or raise BadResponseError, "Command #{@command} is expected, but command: #{command}: #{body}"
        # the forth parameter could be nil in the inter-crepd communication, so do not block it
        # args.class == Hash or raise BadResponseError, "The forth parameter is not a Hash: #{args}: #{body}"
        a.size == 4 or raise BadResponseError, "The number of parameters does not equal to 4: #{a.size}: #{body}"
        [ command, args ]
      end
    end


    class TcpClientChannel < ClientChannel
      def send( socket, command, args )
        s = "#{super}\r\n"
        socket.syswrite( s )
        if ( $DEBUG )
          # @port, @ip = socket.peeraddr[1], socket.peeraddr[3]
          @port, @ip = Socket.unpack_sockaddr_in( socket.getpeername )
          Log.debug( sprintf( "TCP O : %s:%s %s", @ip, @port, s ) )
        end
      end

      def receive( socket )
        @data = socket.gets

        if ( closed? )
          socket.close unless socket.closed?
        end

        if ( $DEBUG )
          # @port, @ip = socket.peeraddr[1], socket.peeraddr[3]
          @port, @ip = Socket.unpack_sockaddr_in( socket.getpeername )
          unless ( @data.nil? )
            Log.debug( sprintf( "TCP I : %s:%s %s", @ip, @port, @data ) )
          else
            Log.debug( sprintf( "TCP Closed   : %s:%s %s", @ip, @port, 'nil' ) )
          end
        end
      end

      def get_peeraddr
        [ @ip, @port ]
      end

      def closed?
        @data.nil? or @data == ''
      end

      def parse
        super( @data )
      end

      def tcp?
        true
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
    end
  end
end
