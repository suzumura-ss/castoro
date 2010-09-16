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
require 'json'
require 'castoro-peer/errors'
require 'castoro-peer/log'

module Castoro
  module Peer

    class Csm
      class DaemonIF
        @@request_expire = 30.0

        def initialize( daemon_socket )
          @daemon_socket = daemon_socket
        end

        def execute( r )
          operand = {
            "mode"  => r.mode,
            "user"  => r.user,
            "group" => r.group,
          }

          case r.subcommand
          when "mkdir"
            opecode = "MKDIR"
            operand["source"] = r.path1
          when "mv"
            opecode = "MV"
            operand["source"] = r.path1
            operand["dest"]   = r.path2
          end

          send_request( ["1.1","C",opecode,operand].to_json + "\r\n" )
        end

        ##
        # send execute request to manipulator daemon.
        #
        def send_request( request )
          Log.debug ( "manipulator request: #{request}" ) if $DEBUG

          # request.
          response = connect_manipulator_daemon { |sock|
            # Use write() here and do not use syswrite() which might block 
            # due to some reasons of the destination process
            sock.write request
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
            Log.warning e, "CSM Daemon connect error #{@daemon_socket}"
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

      class CommandIF
        @@csm = File.join(File.dirname(__FILE__), '..', '..', 'csm')

        def execute( r )
          command = "#{@@csm} #{r.subcommand} -u #{r.user} -g #{r.group} -m #{r.mode} #{r.path1} #{r.path2}"
          Log.debug( command ) if $DEBUG
          output = `#{command} 2>&1`
          status = $?.exitstatus
          unless ( status == 0 )
            Log.warning( "CSM Error: #{command} ; exit status: #{status}" )
            raise CommandExecutionError, "#{command} ; exit status: #{status}"
          end
        end
      end
    end

  end
end

