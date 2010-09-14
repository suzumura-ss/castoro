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
require 'castoro-peer/server_status'
require 'castoro-peer/cpeerd_workers'

module Castoro
  module Peer

    class CpeerdMain < Main
      def initialize
        super
        @w = CpeerdWorkers.instance
      end

      def start
        @w.start_maintenance_server
        @w.start_workers
        super
      end

      def stop
        @w.stop_workers
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
  $LOAD_PATH.dup.each { |x|
    $LOAD_PATH.delete x if x.match '\/gems\/'
  }

  m = Castoro::Peer::CpeerdMain.instance
  Castoro::Peer::ServerStatus.instance.status_name = 'offline'
  m.main_loop
end
