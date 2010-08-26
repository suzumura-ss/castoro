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
require "thread"

module Castoro
  class Gateway
    ##
    # Castoro::Gateway's worker threads.
    #
    class Workers < Castoro::Workers

      def initialize logger, count, facade, repository, multicast_addr, device_addr, multicast_port
        super logger, count
        @facade     = facade
        @repository = repository
        @addr       = multicast_addr
        @device     = device_addr
        @port       = multicast_port
      end

    private

      def work
        Sender::UDP::Multicast.new(@logger, @port, @addr, @device) { |s|
          nop = Protocol::Response::Nop.new(nil)

          until Thread.current[:dying]
            begin
              if (recv_ret = @facade.recv)
                h, d = recv_ret

                case d
                when Protocol::Command::Create
                  res = @repository.fetch_available_peers d
                  s.send h, res, h.ip, h.port

                when Protocol::Command::Get
                  res = @repository.query d
                  if res
                    s.send h, res, h.ip, h.port
                  else
                    s.multicast h, d
                  end

                when Protocol::Command::Insert
                  @repository.insert_cache_record d

                when Protocol::Command::Drop
                  @repository.drop_cache_record d

                when Protocol::Command::Alive
                  @repository.update_watchdog_status d

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
