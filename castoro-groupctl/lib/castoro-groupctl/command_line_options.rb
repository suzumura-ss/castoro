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

require 'getoptlong'
### require 'castoro-peer/configurations'

module Castoro
  module Peer

    class CommandLineOptions < GetoptLong
      def initialize
        @program_name = $0.sub(/.*\//, '')
        super(
              [ '--help',                '-h', NO_ARGUMENT ],
              [ '--version',             '-V', NO_ARGUMENT ],
              [ '--verbose',             '-v', NO_ARGUMENT ],
              [ '--debug',               '-d', NO_ARGUMENT ],
              [ '--foreground',          '-f', NO_ARGUMENT ],
              [ '--configuration-file',  '-c', REQUIRED_ARGUMENT ],
              )

        each do |opt, arg|
          case opt
          when '--help'
            usage
            exit 0
          when '--version'
            puts "#{@program_name} - Version #{PROGRAM_VERSION}"
            exit 0
          when '--verbose'
            $VERBOSE = true
          when '--debug'
            $DEBUG = true
          when '--foreground'
            $RUN_AS_DAEMON = false
###          when '--configuration-file'
###            Configurations.file = arg
          end
        end
      end

      def usage
        puts "#{@program_name} - Version #{PROGRAM_VERSION}"
        puts ""
        puts " Usage: #{@program_name} [options]"
        puts ""
        puts "  options:"
        puts "   -h, --help"
        puts "   -V, --version"
        puts "   -v, --verbose"
        puts "   -d, --debug"
        puts "   -f, --foreground"
        puts "   -c configuration_file, --configuration-file=configuration_file"
        puts ""
      end
    end

  end
end
