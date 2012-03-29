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

require 'singleton'
require 'castoro-peer/configurations'

module Castoro
  module Peer

    class StorageServers
      include Singleton

      attr_reader :members, :myhost, :target, :alternative_hosts, :colleague_hosts

      def initialize
        c = Configurations.instance
        hostname = c.peer_hostname
        storages = c.StorageHostsData
        groups = c.StorageGroupsData
        g = groups.select { |a| a.include? hostname }
        g.flatten!
        n = g.size
        g.concat g.dup
        i = g.index( hostname )
        hosts = g.slice(i, n)
        h = hosts.map { |x| storages[ x ] || x }
        @members = h.dup
        @myhost = h.shift
        @colleague_hosts = h.dup
        @target = h.shift
        @alternative_hosts = h
      end
    end
  end
end
