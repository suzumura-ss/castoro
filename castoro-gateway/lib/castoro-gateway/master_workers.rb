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

require "logger"

module Castoro
  class Gateway
    ##
    # Castoro::Gateway's worker threads.
    #
    class MasterWorkers < Castoro::Workers

      def initialize logger, count, facade, broadcast_addr, device_addr, broadcast_port
        super logger, count
        @facade = facade
        @addr   = broadcast_addr
        @device = device_addr
        @port   = broadcast_port
      end

    private

      def work
        Sender::UDP::Broadcast.start(@logger, @port, @addr) { |s|
          nop = Protocol::Response::Nop.new(nil)

          until Thread.current[:dying]
            begin
              if (recv_ret = @facade.recv)
                h, d = recv_ret

                case d
                when Protocol::Command::Create
                  #

                when Protocol::Command::Get
                  if d.island
                    #
                  else
                    s.broadcast h, d
                  end

                when Protocol::Command::Island
                  #
                  
                when Protocol::Command::Nop
                  s.send h, nop, h.ip, h.port

                else
                  # do nothing.
                end

              end

            rescue => e
              @logger.error { e.message }
              @logger.debug { e.backtrace.join("\n\t") }
            end
          end
        }
      end

    end
  end
end
