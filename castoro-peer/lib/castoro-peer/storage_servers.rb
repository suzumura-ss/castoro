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

require 'yaml'
require 'json'
require 'castoro-peer/ifconfig'
require 'castoro-peer/configurations'
require 'castoro-peer/log'

module Castoro
  module Peer

    class StorageServers
      include Singleton

      def initialize
        @index = 0
        load
      end

      def load
        c = Configurations.instance
        @host = c.HostnameForClient
        storages = YAML::load_file( c.StorageHostsYaml )
        groups = JSON::parse IO.read( c.StorageGroupsJson )

        g = groups.select { |a| a.include? @host }
        g.flatten!
        n = g.size
        g.concat g.dup
        i = g.index( @host )
        hosts = g.slice(i, n)
        h = hosts.map { |x| storages[ x ] || x }
        h.shift
        @colleague_hosts = h.dup
        @replication_target_host = h.shift
        @replication_aliternative_hosts = h
      end

      def my_host
        @host
      end

      def target
        @replication_target_host
      end
      
      def alternative_hosts
        @replication_aliternative_hosts
      end

      def colleague_hosts
        @colleague_hosts
      end
    end
  end
end
