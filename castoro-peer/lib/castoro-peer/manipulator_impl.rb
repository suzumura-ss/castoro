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
      class DaemonInterface
        @@timed_out = 30

        def initialize( unix_socket_name )
          @unix_socket_name = unix_socket_name
        end

        def execute( r )
          operand = {
            "mode"  => r.mode,
            "user"  => r.user,
            "group" => r.group,
          }

          case r.subcommand
          when "mkdir"
            opcode = "MKDIR"
            operand["source"] = r.path1
          when "mv"
            opcode = "MV"
            operand["source"] = r.path1
            operand["dest"]   = r.path2
          end

          command = ["1.1","C",opcode,operand].to_json
          Log.debug( "CSM C: #{command}" ) if $DEBUG
          response = send_command( "#{command}\r\n" )
          Log.debug( "CSM R: #{response}" ) if $DEBUG

          version, direction, opcode, operand = JSON.parse response
          error = operand["error"]
          if ( error )
            raise CommandExecutionError, "CSM daemon error: #{error["code"]} #{error["message"]}: #{command}"
          end
        end

        ##
        # send a command to the manipulator daemon.
        #
        def send_command( command )
          s = nil
          begin
            s = UNIXSocket.open @unix_socket_name
          rescue => e
            raise CommandExecutionError, "CSM daemon error: connection failed: #{e.class} #{e.message}: #{@unix_socket_name} #{@command}"
          end
          s.syswrite command
          if ( IO.select( [s], nil, nil, @@timed_out ) )
            return s.gets
          else
            raise CommandExecutionError, "CSM daemon error: response timed out: #{@@timed_out}s #{@command}"
          end
        ensure
          s.close if s
        end
      end


      class CommandInterface
        @@csm = File.join(File.dirname(__FILE__), '..', '..', 'csm')

        def execute( r )
          command = "#{@@csm} #{r.subcommand} -u #{r.user} -g #{r.group} -m #{r.mode} #{r.path1} #{r.path2}"
          Log.debug( command ) if $DEBUG
          output = `#{command} 2>&1`
          status = $?.exitstatus
          unless ( status == 0 )
            raise CommandExecutionError, "CSM command error: #{command} ; exit status: #{status}"
          end
        end
      end
    end

  end
end

