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

require 'castoro-groupctl/main'
require 'castoro-groupctl/cagentd_workers'
require 'castoro-groupctl/command_line_options'

module Castoro
  module Peer

    class CagentdMain < Main
      def initialize
        super
        CommandLineOptions.new
      end

      def setup
        super( :effective_user => Configurations.instance.effective_user )
        @w = CagentdWorkers.new
      end

      def start
        @w.start
        super
      end

      def stop
        super
        @w.stop
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

  Castoro::Peer::CagentdMain.instance.run
end
