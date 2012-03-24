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

    class Channel
      def initialize
        @command = nil
      end

      module TcpModule
        def tcp?
          true
        end

        def closed?
          @data.nil? or @data == ''
        end

        def parse
          super @data
        end

        def receive socket, ticket = nil
          @data = socket.gets
          ticket.mark unless ticket.nil?
          if closed?
            socket.close unless socket.closed?
          end
          if $DEBUG
            unless closed?
              Log.debug "TCP I : #{socket.ip}:#{socket.port} #{@data}"
            else
              Log.debug "TCP Closed : #{socket.ip}:#{socket.port}"
            end
          end
        end
      end

      module UdpModule
        def tcp?
          false
        end
      end
    end


    class ServerChannel < Channel
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
      include Channel::TcpModule

      def send( socket, result, ticket = nil )
        s = "#{super}\r\n"
        ticket.mark unless ticket.nil?
        socket.syswrite( s )
        ticket.mark unless ticket.nil?
        if $DEBUG
          Log.debug "TCP O : #{socket.ip}:#{socket.port} #{s}"
        end
      end
    end


    class UdpServerChannel < ServerChannel
      include Channel::UdpModule

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
    end


    class UdpMulticastClientChannel
      include Channel::UdpModule

      def initialize( socket )
        @socket = socket
        @reply_ip = Configurations.instance.MulticastIf
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


    class ClientChannel < Channel
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
      include Channel::TcpModule

      def send( socket, command, args )
        s = "#{super}\r\n"
        socket.syswrite( s )
        if $DEBUG
          Log.debug "TCP O : #{socket.ip}:#{socket.port} #{s}"
        end
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
