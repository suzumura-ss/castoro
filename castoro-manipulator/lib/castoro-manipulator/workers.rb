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

require "rubygems"

require "castoro-manipulator"

module Castoro
  class Manipulator

    class Workers < Castoro::Workers

      include WorkersHelper

      ##
      # initialize.
      #
      def initialize logger, count, facade, base_dir
        super logger, count
        @facade, @base_dir = facade, base_dir
      end

      private

      ##
      # work action.
      #
      def work
        
        # client loop..
        @facade.client_loop { |socket, received|

          # accept.
          accept_command(socket, received) { |cmd|

            case cmd
            when Protocol::Command::Mkdir

              # mkdir execute.
              unless cmd.source =~ /^#{@base_dir}.*$/
                raise ManipulatorError, "Invalid source directory - #{cmd.source}"
              end
              @logger.info { "MKDIR #{cmd.mode},#{cmd.user},#{cmd.group},#{cmd.source}" }
              Command.new_recursive_mkdir(cmd.source, cmd.mode, cmd.user, cmd.group).invoke

              # response.
              res = Protocol::Response::Mkdir.new(nil)
              send_response(socket, res)

            when Protocol::Command::Mv

              # mv execute.
              unless cmd.source =~ /^#{@base_dir}.*$/
                raise ManipulatorError, "Invalid source directory - #{cmd.source}"
              end
              unless cmd.dest =~ /^#{@base_dir}.*$/
                raise ManipulatorError, "Invalid dest directory - #{cmd.dest}"
              end
              @logger.info { "MOVE  #{cmd.mode},#{cmd.user},#{cmd.group},#{cmd.source},#{cmd.dest}" }
              Command.new_recursive_move(cmd.source, cmd.dest, cmd.mode, cmd.user, cmd.group).invoke

              # response.
              res = Protocol::Response::Mv.new(nil)
              send_response(socket, res)

            else
              raise ManipulatorError, "only Mkdir, Mv and Nop are accepted."
            end

          }
        }

      end

    end
  end
end
