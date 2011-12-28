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
    class Repository

      def initialize logger, config
        @logger = logger
        @cache  = ::Castoro::BasketCache.new @logger, config
      end

      ##
      # get response from peer or cache.
      #
      # === Args
      #
      # +command+::
      #   get command instance.
      #
      def query command
        hit = !!(res = query_from_cached_data(command))
        @logger.info { "[key:#{command.basket}] cache hit => #{hit}" }
        res
      end

      ##
      # fetch available peer(s) from cache.
      #
      # === Args
      #
      # +command+::
      #   create command instance.
      #
      def fetch_available_peers command
        peers = @cache.preferentially_find_peers command.hints

        if peers.empty?
          @logger.warn { "[key:#{command.basket}] It failed in the selection of Peer." }
          command.error_response :message => "It failed in the selection of Peer."
        else
          @logger.info { "[key:#{command.basket}] fetch peers <#{peers}>" }
          Protocol::Response::Create::Gateway.new(nil, command.basket, peers)
        end
      end

      ##
      # insert cache record.
      #
      # === Args
      #
      # +data+::
      #   insert command instance.
      #
      def insert_cache_record command
        elems = command.path.split("/")
        base_path = elems[0..(elems.size-4-1)].join("/")
        @logger.info { "[key:#{command.basket}] insert cache <#{command.host}> <#{base_path}>" }
        @cache.insert command.basket, command.host, base_path
      end

      ##
      # drop cache record.
      #
      # === Args
      #
      # +data+::
      #   drop command instance.
      #
      def drop_cache_record command
        @logger.info { "[key:#{command.basket}] drop cache <#{command.host}>" }
        @cache.erase_by_peer_and_key command.host, command.basket
      end

      ##
      # update watchdog status for cache.
      #
      # === Args
      #
      # +data+::
      #   alive command instance.
      #
      def update_watchdog_status command
        @cache.set_status(command.host, command.status, command.available)
      end

      ##
      # The status of hash representation is returned.
      #
      def status
        @cache.status
      end

      ##
      # cache record is dumped.
      #
      # === Args
      #
      # +io+::
      #   IO object that receives dump result.
      #
      def dump io
        @cache.dump io
      end 

      ##
      # get storables.
      #
      def storables
        @cache.active_peer_count
      end

      ##
      # get capacity. 
      #
      def capacity
        @cache.available_total_space
      end

    private

      ##
      # get response from cache.
      #
      # === Args
      #
      # +command+::
      #   get command instance.
      #
      def query_from_cached_data command
        paths = @cache.find_by_key(command.basket)
        return nil if paths.empty?

        Protocol::Response::Get.new(false, command.basket, paths)
      end

    end
  end
end
