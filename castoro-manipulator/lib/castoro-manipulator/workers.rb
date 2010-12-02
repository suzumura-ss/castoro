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

module Castoro #:nodoc:
  module Manipulator #:nodoc:

    class Workers < Castoro::Workers

      include WorkersHelper

      ##
      # initialize.
      #
      def initialize logger, count, facade, base_dir
        super logger, count
        @facade = facade
        @executor = Executor.new @logger, :base_directory => base_dir
      end

      private

      ##
      # work action.
      #
      def work

        ok_response_mkdir = Protocol::Response::Mkdir.new(nil)
        ok_response_move  = Protocol::Response::Mv.new(nil)
        
        # client loop..
        @facade.client_loop { |socket, received|

          # accept.
          accept_command(socket, received) { |cmd|

            case cmd
            when Protocol::Command::Mkdir

              # mkdir execute and response.
              @executor.mkdir cmd.mode, cmd.user, cmd.group, cmd.source
              send_response(socket, ok_response_mkdir)

            when Protocol::Command::Mv

              # mv execute and response.
              @executor.move cmd.mode, cmd.user, cmd.group, cmd.source, cmd.dest
              send_response(socket, ok_response_move)

            else
              raise ManipulatorError, "only Mkdir, Mv and Nop are accepted."
            end

          }
        }

      end

    end
  end
end

