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

require 'castoro-groupctl/proxy'
require 'castoro-groupctl/peer_component'
require 'castoro-groupctl/peer_group_component'

module Castoro
  module Peer

    class ProxyPool
      include Singleton

      attr_reader :entries

      def initialize
        @entries = {}
      end

      def add_peer hostname
        @entries[ hostname ] = {
          :cmond        => CmondProxy.new( hostname ),
          :cpeerd       => CpeerdProxy.new( hostname ),
          :crepd        => CrepdProxy.new( hostname ),
          :manipulatord => ManipulatordProxy.new( hostname ),
        }
      end

      def get_peer hostname
        PeerComponent.new hostname, @entries[ hostname ]
      end

      def get_the_first_peer
        get_peer @entries.keys[0]
      end

      def get_the_rest_of_peers
        x = @entries.dup
        x.delete( x.keys[0] )
        PeerGroupComponent.new x
      end

      def get_peer_group
        PeerGroupComponent.new @entries
      end
    end

  end
end
