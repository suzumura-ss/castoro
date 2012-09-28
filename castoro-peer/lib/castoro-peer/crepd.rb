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

if $0 == __FILE__
  $LOAD_PATH.dup.each { |x| $LOAD_PATH.delete x if x.match '\/gems\/' }
  $LOAD_PATH.unshift ".."
  $LOAD_PATH.unshift "../../../castoro-common/lib"
end

require 'castoro-peer/main'
require 'castoro-peer/server_status'
require 'castoro-peer/crepd_workers'
#require './ruby_tracer' ; RubyTracer.open "trace-#{$$}.log"

module Castoro
  module Peer

    class CrepdMain < Main
      def initialize
        #RubyTracer.enable
        super
        ReplicationQueueDirectories.instance.salvage
        @w = ReplicationWorkers.new
        #RubyTracer.enable
      end

      def start
        @w.start_workers
        #RubyTracer.enable
        super
      end

      def stop
        #RubyTracer.enable
        super
        @w.stop_workers
        quit
      end
    end

  end
end


################################################################################
# Please Do Not Remvoe the Following Code. It is used for development efforts.
################################################################################

if $0 == __FILE__
  m = Castoro::Peer::CrepdMain.instance
  Castoro::Peer::ServerStatus.instance.status_name = 'offline'
  m.main_loop
end
