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

require "castoro-common"

module Castoro

  ##
  # helper for Castoro::Workers class.
  #
  # The following functions are offered by doing include.
  # 
  # * Protocol analysis of reception packet
  # * Response when parse error
  # * Response when NOP is received
  # * United response means
  #
  # === Examples.
  #
  # # TestWorkers class inherits Casotor::Workers.
  # class TestWorkers < Castoro::Workers
  #
  #   include WorkersHelper # include
  #
  #   # The instance of Castoro::Server is passed by the argument. 
  #   def initialize logger, server
  #     super logger, 1
  #     @server = server
  #   end
  #
  #   # Main process.
  #   def work
  #     @server.client_loop { |client, received|
  #       accept_command(client, received) { |command|
  #
  #         # received that is raw data has been converted into command.
  #         # command.class => Castoro::Protocol::Command
  #
  #         case command
  #         when Castoro::Protocol::Command::Status
  #           res = Castoro::Protocol::Response::Status.new(nil, "foo" => "bar")
  #           send_response(client, res)
  #
  #         else
  #           # The exception generated in block is
  #           # appropriately answered as an error response.
  #           raise CastoroError, "only Nop, Status is accepted."
  #         end
  #
  #       }
  #     }
  #   end
  #
  # end
  #
  module WorkersHelper

    ##
    # The packet is accepted.
    #
    # The reception packet is parsed in Protocol
    # and only when it is necessary, the block is evaluated. 
    #
    def accept_command client, packet

      @logger.debug { "recv #{packet.chomp}" }

      # parse command.
      begin
        command = Protocol.parse packet
        raise WorkersError, "unsupported packet type." unless command.kind_of?(Protocol::Command)
      rescue => e
        @logger.warn { e.message }
        res = Protocol::Response.new("code" => e.class.to_s, "message" => e.message)
        return send_response(client, res)
      end

      begin
        case command
        when Protocol::Command::Nop
          send_response(client, Protocol::Response::Nop.new(nil))

        else Protocol::Command
          yield command
        end

      rescue => e
        @logger.warn { e.message }
        res = command.error_response("code" => e.class.to_s, "message" => e.message)
        send_response(client, res)
      end
    end

    ##
    # Send response.
    #
    # === Args
    #
    # +client+::
    #   socket for client.
    # +response+::
    #   response serialized data packet.
    #
    def send_response client, response
      res = response.to_s
      @logger.debug { "send #{res.chomp}" }
      client.puts(res)
    end

  end
end

