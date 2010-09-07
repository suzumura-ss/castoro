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

require "castoro-gateway"

module Castoro
  class Gateway

    class ConsoleWorkers < Castoro::Workers

      include WorkersHelper

      ##
      # initialize.
      #
      def initialize logger, facade, gateway
        super logger, 1, :name => "console"
        @facade, @gateway = facade, gateway
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
            when Protocol::Command::Status
              # response.
              res = Protocol::Response::Status.new(nil, @gateway.status)
              send_response(socket, res)

            else
              raise GatewayError, "only Status and Nop are accepted."
            end

          }
        }

      end

    end
  end
end
