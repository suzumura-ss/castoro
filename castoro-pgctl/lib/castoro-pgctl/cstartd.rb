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
  $LOAD_PATH.dup.each do |x|
    $LOAD_PATH.delete x if x.match %r(/gems/)
  end
  $LOAD_PATH.unshift '..'
end

require 'castoro-pgctl/main'
require 'castoro-pgctl/cstartd_workers'
require 'castoro-pgctl/command_line_options'

module Castoro
  module Peer

    class CstartdMain < Main
      def initialize
        super
        CommandLineOptions.new
      end

      def setup
        super( :effective_user => 'root' )
        @w = CstartdWorkers.new
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

if $0 == __FILE__
  Castoro::Peer::CstartdMain.instance.run
end
