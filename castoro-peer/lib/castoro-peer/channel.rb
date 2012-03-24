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

      def parse body, direction_code, exception
        a = JSON.parse body
        version, direction, command, args = a
        @command = command  # @command will be used in a response whatever exception occurs
        a.size == 4 or raise exception, "The number of parameters does not equal to 4: #{a.size}: #{body}"
        version == PROTOCOL_VERSION or raise exception, "Version #{PROTOCOL_VERSION} is expected: #{version}: #{body}"
        direction == direction_code or raise exception, "Direction #{direction_code} is expected: #{direction}: #{body}"
        [ command, args ]
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
          ticket.mark unless ticket.nil?
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
      def parse body
        super body, 'C', BadRequestError
      end

      def send socket, result, ticket = nil
        if result.is_a? Exception
          [ PROTOCOL_VERSION, 'R', @command, 
            { 'error' => { 'code' => result.class, 'message' => result.message } } ].to_json
        else
          [ PROTOCOL_VERSION, 'R', @command, result ].to_json
        end
      end
    end


    class TcpServerChannel < ServerChannel
      include Channel::TcpModule

      def send socket, result, ticket = nil
        s = super
        ticket.mark unless ticket.nil?
        socket.syswrite( "#{s}\r\n" )
        ticket.mark unless ticket.nil?
        Log.debug "TCP O : #{socket.ip}:#{socket.port} #{s}" if $DEBUG
      end
    end


    class UdpServerChannel < ServerChannel
      include Channel::UdpModule

      def receive socket, ticket = nil
        @data = socket.receiving( ticket )
        ticket.mark unless ticket.nil?
      end

      def parse
        @header, body = @data.split("\r\n")
        a = JSON.parse @header
        a.size == 3 or raise BadRequestError, "The number of parameters does not equal to 3: #{a.size}: #{@header}"
        @ip, @port, @sid = a
        # Todo: validation on ip, port, sid
        super body
      end

      def send socket, result, ticket = nil
        socket.sending( "#{@header}\r\n#{super}\r\n", @ip, @port, ticket )
      end
    end


    class ClientChannel < Channel
      def send socket, command, args
        @command = command
        [ PROTOCOL_VERSION, 'C', command, args ].to_json
      end

      def parse body
        sent_command = @command
        command, args = super body, 'R', BadResponseError
        sent_command == command or raise BadResponseError, "Command #{sent_command} is expected: #{command}: #{body}"
        [ command, args ]
      end
    end


    class TcpClientChannel < ClientChannel
      include Channel::TcpModule

      def send socket, command, args
        s = super
        socket.syswrite( "#{s}\r\n" )
        Log.debug "TCP O : #{socket.ip}:#{socket.port} #{s}" if $DEBUG
      end
    end


    class UdpClientChannel < ClientChannel
      include Channel::UdpModule

      def initialize socket
        @socket = socket
      end

      def send command, args, ip, port
        sid = SessionIdGenerator.instance.generate
        # Todo: peer does not expect any response from a receipient
        header = [ '0.0.0.0', 0, sid ].to_json  # reply id, reply port, sid
        body   = super socket, command, args
        @socket.sending( "#{header}\r\n#{body}\r\n", ip, port )
      end
    end


    class UdpMulticastClientChannel < UdpClientChannel
      # same as UdpClientChannel
    end
  end
end
