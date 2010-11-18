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

require 'castoro-peer/main'
require 'castoro-peer/crepd_workers'
require 'castoro-peer/crepd_receiver'

module Castoro
  module Peer

    class CrepdMain < Main
      def initialize
        super
        @w = ReplicationWorkers.new @config
        @r = TCPReplicationServer.new @config, @config[:replication_tcp_communication_port]
      end

      def start
        @w.start_maintenance_server
        @r.start
        @w.start_workers
        super
      end

      def stop
        @w.stop_workers
        @r.graceful_stop
        @w.stop_maintenance_server
        super
      end
    end

  end
end


################################################################################
# Please Do Not Remvoe the Following Code. It is used for development efforts.
################################################################################

if $0 == __FILE__
  require 'castoro-peer/server_status'

  $LOAD_PATH.dup.each { |x|
    $LOAD_PATH.delete x if x.match '\/gems\/'
  }

  m = Castoro::Peer::CrepdMain.instance
  Castoro::Peer::ServerStatus.instance.status_name = 'offline'
  m.main_loop
end
