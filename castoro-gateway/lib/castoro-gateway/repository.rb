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
        @replication_count = config["replication_count"] || 3
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
      # +island+::
      #   island id.
      #
      def fetch_available_peers command, island
        peers = @cache.preferentially_find_peers command.hints

        if peers.empty?
          @logger.warn { "[key:#{command.basket}] It failed in the selection of Peer." }
          command.error_response :message => "It failed in the selection of Peer."
        else
          @logger.info { "[key:#{command.basket}] fetch peers <#{peers}>" }
          Protocol::Response::Create::Gateway.new(nil, command.basket, peers, island)
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
        @logger.info { "[key:#{command.basket}] insert cache <#{command.host}>" }
        @cache.insert command.basket, command.host
      end

      ##
      # drop cache record from command.
      #
      # === Args
      #
      # +data+:: drop command instance.
      #
      def drop_cache_record command
        drop command.basket, command.host
      end

      ##
      # drop cache record.
      #
      # === Args
      #
      # +basket+ :: basket key.
      # +peer+   :: hostname for peer.
      #
      def drop basket, peer
        @logger.info { "[key:#{basket}] drop cache <#{peer}>" }
        @cache.erase_by_peer_and_key peer, basket
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
      # +io+    :: IO object that receives dump result.
      # +peers+ :: array of peer name.
      #
      def dump io, peers = nil
        @cache.dump io, peers
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

      ##
      # when replication is Insufficient, block is evaluated.
      #
      # === Args
      #
      # +peers+ :: array of peer(s)
      #
      def if_replication_is_insufficient peers
        if peers.size < @replication_count
          yield if @cache.all_active? peers
        end
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

        Protocol::Response::Get.new(false, command.basket, paths, command.island)
      end

    end
  end
end

