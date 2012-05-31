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

module Castoro
  module Peer

    class SignalHandler
      @@interrupted = false
      @@program = $0.sub( %r{.*/}, '' )  # name of this program
      
      def self.setup
        Signal.trap('INT')  { signal_handler_INT  }  # 2: Interrupt, Ctrl-C
      end

      def self.signal_handler_INT
        STDERR.puts "\nInterrupted. #{@@program} will quit at the next cancellation point.\n\n"
        @@interrupted = true
      end

      def self.interrupted?
        @@interrupted
      end

      def self.check
        if @@interrupted
          STDERR.puts "\n#{@@program} quit by the interruption.\n\n"
          Process.exit 3
        end
      end

      def self.final_check
        if @@interrupted
          STDERR.puts "\n#{@@program} was interrupted but is finished before a cancellation point comes.\n\n"
          Process.exit 0
        end
      end
    end

  end
end
