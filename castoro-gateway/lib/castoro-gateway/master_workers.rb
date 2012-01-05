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

      def initialize logger, count, facade, broadcast_addr, device_addr, port
        super logger, count
        @facade  = facade
        @addr    = broadcast_addr
        @device  = device_addr
        @port    = port
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
                  @island_status.create_relay h, d

                when Protocol::Command::Get
                  if d.island
                    @island_status.get_relay h, d
                  else
                    s.broadcast h, d
                  end

                when Protocol::Command::Island
                  @island_status.set d
                  
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

      def on_starting
        @island_status = IslandStatus.new @logger, @port, @device
        @island_status.start
      end

      def on_stooped
        @island_status.stop
      end

      class IslandStatus
        def initialize logger, port, device
          @logger, @port, @device = logger, port, device
          @locker = Monitor.new
        end

        # start island status.
        #
        def start
          @locker.synchronize {
            @senders = Hash.new { |h,k|
              island = k.to_island
              h[island] = Sender::UDP::Multicast.new(@logger, @port, island.to_ip, @device).tap { |s| s.start }
            }
            @status = {}
          }
        end

        # stop island status.
        #
        def stop
          @locker.synchronize {
            @senders.each { |k,v| v.stop }
            @senders = nil
            @status = nil
          }
        end

        def set island_command
          @status[island_command.island] = {
            :storables => island_command.storables,
            :capacity => island_command.capacity,
          }
          self
        end

        def create_relay create_header, create_command
          island = choice_island(create_command)
          sender(island).multicast(create_header, create_command)
        end

        def get_relay get_header, get_command
          island = get_command.island
          sender(island).multicast(get_header, get_command)
        end

        private

        def sender island
          @senders[island]
        end

        def choice_island create_command
          weight = (0..(@status.size-1)).map { |x| 2**x }
          i = -1
          @status.select { |island, val|
            val[:capacity] >= create_command.capacity
          }.map { |k,v|
            # should sort by capacity
          }
        end
      end

    end
  end
end

