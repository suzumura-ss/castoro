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

require "castoro-gateway-kyotocabinet"

require "monitor"
require 'kyotocabinet'
require 'msgpack'

module Castoro
  class Cache

    ##
    # Substitutes for cache made by C++
    #
    # It is having structure strong against random access. 
    # However, there is much memory usage and its space efficiency is bad. 
    #
    class KyotoCabinet

      attr_reader :watchdog_limit

      # Initialize.
      #
      # === Args
      #
      # +size+:: cache size
      #
      # === options argument detials.
      #
      # :watchdog_limit             :: watchdog limit second (default: 15)
      # :logger                     :: the logger instance.
      # :path_derive_proc           :: base-path derive procedure (default: "/expdsk/#{type}/baskets/a")
      # :compress_derivatable_data  :: If value is same as path_derive_proc evaluation value, set to nil. (default: true)
      #
      def initialize cache_size, options = {}
        raise ArgumentError, "Cache size must be > 0." unless cache_size > 0
        @watchdog_limit     = options[:watchdog_limit] || 15
        @logger             = options[:logger]

        @map             = Map.new(cache_size, options)
        @peers           = Hash.new { |h,k| h[k] = Peer.new }
        @finds           = 0
        @hits            = 0
      end

      # A cache element is searched.
      #
      # The arrangement of the NFS path of an object element is returned. 
      #
      # === Args
      #
      # +id+    :: Basket Id
      # +type+  :: Basket Type
      # +rev+   :: Basket Revision
      #
      def find id, type, rev
        @finds += 1
        expired = Time.now.to_i - @watchdog_limit
        @map.get(id, type, rev).map { |peer, base|
          ::Castoro::Cache.make_nfs_path(peer, base, id, type, rev) if @peers[peer.to_sym].alive?(expired)
        }.compact.tap { |ret|
          @hits += 1 unless ret.empty?
        }
      end

      # cache status is returned.
      #
      # === Args
      #
      # +key+ :: status key
      #
      def stat key
        case key
          when ::Castoro::Cache::DSTAT_CACHE_EXPIRE     ; @watchdog_limit
          when ::Castoro::Cache::DSTAT_CACHE_REQUESTS   ; @finds
          when ::Castoro::Cache::DSTAT_CACHE_HITS       ; @hits
          when ::Castoro::Cache::DSTAT_CACHE_COUNT_CLEAR; (@finds == 0 ? 0 : @hits * 1000 / @finds).tap { |ret| @finds = @hits = 0 }
          when ::Castoro::Cache::DSTAT_ALLOCATE_PAGES   ; 0 # In RandomCache There is no concept of a page segment. 
          when ::Castoro::Cache::DSTAT_FREE_PAGES       ; 0 # In RandomCache There is no concept of a page segment. 
          when ::Castoro::Cache::DSTAT_ACTIVE_PAGES     ; 0 # In RandomCache There is no concept of a page segment. 
          when ::Castoro::Cache::DSTAT_HAVE_STATUS_PEERS; @peers.count { |k,v| v.has_status? }
          when ::Castoro::Cache::DSTAT_ACTIVE_PEERS     ; @peers.count { |k,v| v.writable? }
          when ::Castoro::Cache::DSTAT_READABLE_PEERS   ; @peers.count { |k,v| v.readable? }
          else                                          ; 0
        end
      end

      # Cache information is dumped.
      #
      # === Args
      #
      # +io+ :: the IO Object 
      #
      def dump io
        @map.each { |id, type, rev, peer, base| ::Castoro::Cache.member_puts io, peer, base, id, type, rev }
      end

      def find_peers require_spaces
        expired = Time.now.to_i - @watchdog_limit
        @peers.select { |k,v| v.alive?(expired) and v.storable?(require_spaces) }.keys.map(&:to_s)
      end

      def insert_element peer, id, type, rev, base
        @map.insert id, type, rev, peer.to_sym, base
      end

      def erase_element peer, id, type, rev
        @map.erase id, type, rev, peer.to_sym
      end

      def get_peer_status peer
        @peers[peer.to_sym].status
      end

      def set_peer_status peer, status
        @peers[peer.to_sym].status = status
      end

      private

      ##
      # The class expressing Peer.
      #
      class Peer

        # Initialize
        #
        def initialize
          @available, @status, @status_received_at = 0, 0, 0
        end

        # Peer status is returned.
        #
        # see #status=
        #
        def status
          { :available => @available, :status => @status, }
        end

        # Setter of status.
        #
        # === Args
        #
        # +status+  :: Hash expressing status
        #
        # === status details
        #
        # Acceptance of the following key values is possible. 
        #
        # +:available+  :: storable capacity.
        # +:status+     :: status code.
        #
        def status= status
          @available = status[:available] if status.key?(:available)
          @status    = status[:status]    if status.key?(:status)
          @status_received_at = Time.now.to_i
          status
        end

        # It is returned whether has status or not. 
        #
        def has_status?; @status > 0; end

        # It is returned whether writing is possible.
        #
        def writable?; @status >= 30; end

        # It is returned whether reading is possible.
        #
        def readable?; @status >= 20; end

        # It is returned whether new Basket is storable. 
        #
        def storable? require_spaces
          return true unless require_spaces
          self.writable? and @available > require_spaces
        end

        # It is returned whether has vital reaction or not.
        # 
        # === Args
        #
        # +expire+::
        #   expiration time
        #
        def alive? expire
          @status_received_at >= expire
        end
      end

      ##
      # Key-Value Store which considered BasketRevision.
      #
      class Map
        # Initialize.
        #
        # === Args
        #
        # +size+    :: cache size.
        # +options+ :: cache options.
        #
        # === options argument detials.
        #
        # :logger                     :: the logger instance.
        # :path_derive_proc           :: base-path derive procedure (default: "/expdsk/#{type}/baskets/a")
        # :compress_derivatable_data  :: If value is same as path_derive_proc evaluation value, set to nil. (default: true)
        #
        def initialize size, options = {}
          @db = ::KyotoCabinet::DB.new
          @db.open("*#capsiz=#{size}")

          @path_derive_proc = options[:path_derive_proc] || Proc.new { |id, type, rev, peer| "/expdsk/#{type}/baskets/a" }
          @compress_derivatable_data = options[:compress_derivatable_data].nil? ? true : options[:compress_derivatable_data]
          @logger = options[:logger]

          @locker = Monitor.new
        end

        # get value.
        #
        # Hash of peer-path pair is returned.
        #
        # === Args
        #
        # +id+    :: BasketId
        # +type+  :: BasketType
        # +rev+   :: BasketRevision
        #
        def get id, type, rev
          k, r = to_keys id, type, rev
          return {} unless (val = @locker.synchronize { @db.get(k) })
          val = MessagePack.unpack(val)
          return {} unless val['r'] == r

          {}.tap { |ret|
            val['ps'].each { |k,v|
              peer = ObjectSpace._id2ref(k)
              ret[peer] = v || @path_derive_proc.call(id, type, rev, peer)
            }
          }
        end

        # insert element
        #
        # === Args
        #
        # +id+    :: BasketId
        # +type+  :: BasketType
        # +rev+   :: BasketRevision
        # +key+   :: peer-id
        # +path+  :: base path.
        #
        def insert id, type, rev, key, path
          path = nil if @compress_derivatable_data and @path_derive_proc.call(id, type, rev, key) == path
          k, r = to_keys id, type, rev

          @locker.synchronize {
            val = @db.get(k)
            val = val ? MessagePack.unpack(val) : {}
            val['ps'] = {} unless val['r'] == r
            val['r']  = r
            val['ps'] = (val['ps'] || {}).tap { |ps| ps[key.object_id] = path }
            @db.set(k, val.to_msgpack)
            self
          }
        end

        # erase element
        #
        # === Args
        #
        # +id+    :: BasketId
        # +type+  :: BasketType
        # +rev+   :: BasketRevision
        # +key+   :: peer-id
        #
        def erase id, type, rev, key
          k, r = to_keys id, type, rev

          @locker.synchronize {
            val = @db.get(k)
            val = val ? MessagePack.unpack(val) : {}
            return self unless val['r'] == r # not found.
            val['ps'].delete(key.object_id)
            if val['ps'].empty?
              @db.remove k
              return self
            end
            @db.set(k, val.to_msgpack)
            self
          }
        end

        # #each
        #
        # Block receives 5 arguments.
        #
        # == Block arguments
        #
        # +id+    :: BasketId
        # +type+  :: BasketType
        # +rev+   :: BasketRevision
        # +peer+  :: Peer ID
        # +base+  :: stored path for peer
        #
        def each
          @db.each { |kv|
            k, v = kv.map { |r| MessagePack.unpack(r) }
            id, type = k.to_s.split(':', 2)
            rev      = v['r']
            peers    = v['ps']
            peers.each { |p, b|
              peer = ObjectSpace._id2ref(p)
              base = b || @path_derive_proc.call(id, type, rev, peer)
              yield [id, type, rev, peer, base]
            }
          }
          self
        end

        private

        def to_keys id, type, rev
          ["#{id}:#{type}".to_msgpack, rev & 255]
        end

      end
    end
  end
end

