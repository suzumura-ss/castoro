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

require 'thread'
require 'socket'
require 'singleton'
require 'castoro-groupctl/components'

module Castoro
  module Peer
    
    class SubCommand
      def initialize
        @args = []
        parse_arguments
      end

      def parse_arguments
        while ( x = ARGV.shift )
          begin
            Socket.gethostbyname x  # determine if the parameter is a hostname
            ARGV.unshift x          # hostname
            break
          rescue SocketError => e
            @args.push x            # not a hostname
          end
        end
      end
    end

    class PsSubCommand < SubCommand
      def run
        # p [ 'ps', @args ]
        XBarrier.instance.reset
        x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = x.number_of_targets + 1
        x.do_ps
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        x.print_ps
      end
    end

    class CommandLineArgumentError < ArgumentError
    end
    
    class GroupctlMain
      include Singleton

      def initialize
        @name = $0.sub( %r{.*/}, '' )  # name of this command
      end

      def parse_command_line_options
      end

      def parse_sub_command
        x = ARGV.shift
        x.nil? and raise CommandLineArgumentError, "No sub-command is given."
        case x
        when 'ps' ; PsSubCommand.new
        else
          raise CommandLineArgumentError, "Unknown sub-command: #{x}"
        end
      end

      def parse_hostnames
        Array.new.tap do |a|  # array of hostnames
          ARGV.each do |x|    # argument
            begin
              Socket.gethostbyname x  # confirm if the argument can be resolved as a hostname.
              a.push x  # hostname
            rescue SocketError => e
              if e.message.match( /node name .* known/ )  # getaddrinfo: node name or service name not known
                raise CommandLineArgumentError, "Unknown hostname: #{x}"
              else
                raise e
              end
            end
          end
        end
      end

      def usage
        puts "usage: #{@name} sub-command [options...] [parameters...] [hostnames..]"
      end

      def run
        command = parse_sub_command
        hostnames = parse_hostnames
        hostnames.each do |h|  # hostname
          ProxyPool.instance.add_peer h
        end
        command.run

      rescue CommandLineArgumentError => e
        STDERR.puts "#{@name}: #{e.message}"
        usage
        Process.exit 1
      end
    end

  end
end

if $0 == __FILE__
  Castoro::Peer::GroupctlMain.instance.run
end
