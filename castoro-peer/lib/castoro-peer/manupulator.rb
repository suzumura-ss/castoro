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

require 'socket'
require 'rubygems'
require 'json'

require 'castoro-peer/errors'
require 'castoro-peer/log'

module Castoro
  module Peer

    class CsmRequest

      ALLOW_COMMANDS = [ "mkdir", "mv"  ]

      @@request_expire = 30.0
      @@csm ||= File.join(File.dirname(__FILE__), '..', '..', 'csm')

      def initialize( config, subcommand, user, group, mode, path1, path2 = "" )
        raise "unsupported subcommand." unless ALLOW_COMMANDS.include?(subcommand)
        raise "mode should set the Numeric or octal number character." unless mode.to_s =~ /^[01234567]{3,}$/
        raise "path2 is indispensable for MV." if subcommand == "mv" and path2.to_s == ""

        # config.
        set_configurations config

        @subcommand, @user, @group, @mode, @path1, @path2 = subcommand, user, group, mode, path1, path2
        @command = "#{@@csm} #{subcommand} -u #{user} -g #{group} -m #{mode} #{path1} #{path2}"
      end

      ##
      # Execute manipulator command.
      #
      def execute
        @use_daemon ? send_request : execute_commandline
      end

      ##
      # Convert to string.
      #
      def to_s
        operand = {
          "mode"  => @mode,
          "user"  => @user,
          "group" => @group,
        }

        case @subcommand
        when "mkdir"
          opecode = "MKDIR"
          operand["source"] = @path1
        when "mv"
          opecode = "MV"
          operand["source"] = @path1
          operand["dest"]   = @path2
        end

        ["1.1","C",opecode,operand].to_json + "\r\n"
      end

      private

      ##
      # configuration initialize.
      #
      # === Args
      #
      # +config+::
      #   configuration
      #
      def set_configurations config
        @use_daemon    = config.UseManipulatorDaemon
        @daemon_socket = config.ManipulatorSocket
      end

      ##
      # execute csm commandline.
      #
      def execute_commandline
        Log.debug( @command ) if $DEBUG
        # system( @command )
        output = `#{@command} 2>&1`
        status = $?.exitstatus
        unless ( status == 0 )
          Log.warning( "CSM Error: #{@command} ; exit status: #{status}" )
          raise CommandExecutionError, "#{@command} ; exit status: #{status}"
        end
      end

      ##
      # send execute request to manipulator daemon.
      #
      def send_request
        request = to_s
        Log.debug ( "manipulator request: #{request}" ) if $DEBUG

        # request.
        response = connect_manipulator_daemon { |sock|
          sock.puts request
          ret = IO.select([sock], nil, nil, @@request_expire)
          if ret
            readable = ret[0]
            readable[0].gets
          end
        }
        unless response
          Log.warning( "CSM Error: request expired.#{request.chomp}" )
          raise CommandExecutionError, "request expired.#{request.chomp}"
        end

        # response.
        parse_response response
      end

      ##
      # Connect to manipulator daemon.
      #
      def connect_manipulator_daemon
        begin
          s = UNIXSocket.open @daemon_socket
        rescue => e
          Log.warning( "CSM Daemon connect error #{@daemon_socket}: #{e.message}" )
          raise
        end

        begin
          yield s
        ensure
          s.close if s
        end
      end

      ##
      # Parse response packet.
      #
      # === Args
      #
      # +response+::
      #   response packet from manipulator daemon request.
      #
      def parse_response response
        version, direction, opecode, operand = JSON.parse response
        if (error = operand["error"])
          Log.warning( "CSM Error: #{error["code"]}, #{error["message"]}" )
          raise CommandExecutionError, "#{error["code"]}, #{error["message"]}"
        end
      end

    end

  end
end

