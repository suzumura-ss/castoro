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
require 'getoptlong'
require 'castoro-groupctl/components'
require 'castoro-groupctl/command_line_options'

module Castoro
  module Peer
    
    class SubCommand
      def initialize
        @options = nil
        parse_arguments
      end

      def parse_arguments
        while ( x = ARGV.shift )
          begin
            Socket.gethostbyname x  # determine if the parameter is a hostname
            ARGV.unshift x          # it is a hostname
            break                   # quit here
          rescue SocketError => e
            # intentionally ignored. it is not a hostname
          end
          x.match( /\A[a-zA-Z0-9_ -]*\Z/ ) or raise CommandLineArgumentError, "Non-alphanumeric letter are given: #{x}"
          @options = [] if @options.nil?
          @options.push x
        end
      end
    end

    class PsSubCommand < SubCommand
      def probe
        XBarrier.instance.reset
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_ps @options
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
      end

      def run
        probe
        @x.print_ps
      end
    end

    class StatusSubCommand < SubCommand
      def probe
        XBarrier.instance.reset
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_status @options
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
      end

      def run
        PsSubCommand.new.probe
        probe
        @x.print_status
      end
    end


    class StartAllSubCommand < SubCommand
      def run
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1

        puts "[ #{Time.new.to_s} Daemon processes ]"
        XBarrier.instance.reset
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_ps nil
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_ps

        sleep 0.01

        unless @x.ps_running?
          puts "[ #{Time.new.to_s} Starting daemons ]"
          XBarrier.instance.reset
          @x.do_start
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_start
          sleep 2

          puts "[ #{Time.new.to_s} Daemon processes ]"
          XBarrier.instance.reset
          @x = ProxyPool.instance.get_peer_group
          XBarrier.instance.clients = @x.number_of_targets + 1
          @x.do_ps nil
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_ps
          sleep 2
        end

        puts "[ #{Time.new.to_s} Status ]"
        XBarrier.instance.reset
        @x.do_status nil
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_status

        unless @x.mode == 30
          puts "[ #{Time.new.to_s} Turning the autopilot of daemon processes off ]"
          XBarrier.instance.reset
          @x.do_auto false
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_auto

          sleep 2

          puts "[ #{Time.new.to_s} Status ]"
          XBarrier.instance.reset
          @x.do_status nil
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_status

          sleep 2

          puts "[ #{Time.new.to_s} Ascending the mode to 30 online ]"
          XBarrier.instance.reset
          @x.ascend_mode 30
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_mode

          sleep 2

          puts "[ #{Time.new.to_s} Status ]"
          XBarrier.instance.reset
          @x.do_status nil
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_status

          sleep 2

          puts "[ #{Time.new.to_s} Turning the autopilot of daemon processes auto ]"
          XBarrier.instance.reset
          @x.do_auto true
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_auto

          sleep 2

          puts "[ #{Time.new.to_s} Status ]"
          XBarrier.instance.reset
          @x.do_status nil
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_status
        end
      end
    end


    class StopAllSubCommand < SubCommand
      def probe
        XBarrier.instance.reset
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_stop
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
      end

      def run
        ps = PsSubCommand.new
        ps.run
        probe
        @x.print_stop
        sleep 1
        ps = PsSubCommand.new
        ps.run
      end
    end


    class CommandLineArgumentError < ArgumentError
    end
    
    class GroupctlMain
      include Singleton

      def initialize
        @program_name = $0.sub( %r{.*/}, '' )  # name of this command
      end

      def parse_command_line_options
        x = GetoptLong.new(
              [ '--help',                '-h', GetoptLong::NO_ARGUMENT ],
              [ '--debug',               '-d', GetoptLong::NO_ARGUMENT ],
              [ '--configuration-file',  '-c', GetoptLong::REQUIRED_ARGUMENT ],
              )

        x.each do |opt, arg|
          case opt
          when '--help'
            usage
            exit 0
          when '--debug'
            $DEBUG = true
          when '--configuration-file'
            Configurations.file = arg
          end
        end
      end

      def parse_sub_command
        x = ARGV.shift
        x.nil? and raise CommandLineArgumentError, "No sub-command is given."
        case x
        when 'ps'       ; PsSubCommand.new
        when 'status'   ; StatusSubCommand.new
        when 'startall' ; StartAllSubCommand.new
        when 'stopall'  ; StopAllSubCommand.new
        when 'stop'     ; StopSubCommand.new
#        when 'mode'     ; ModeSubCommand.new
#        when 'auto'     ; AutoSubCommand.new
#        when ''  ; SubCommand.new
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
        puts "usage: #{@program_name} [global options...] sub-command [options...] [parameters...] [hostnames..]"
        puts ""
        puts "  global options:"
        puts "   -h, --help"
        puts "   -d, --debug"
        puts "   -c configuration_file, --configuration-file=configuration_file"
        puts ""
        puts "  sub commands:"
        puts "   ps         lists the deamon processes in a 'ps -ef' format"
        puts "   status     shows the status of the deamon processes"
        puts "   startall   starts deamon processes on every host of the group"
        puts "   stop       stops daemon processes on the only tartget host"
        puts "   stopall    stops daemon processes on every host of the group"
        puts ""

      end

      def run
        parse_command_line_options
        command = parse_sub_command
        hostnames = parse_hostnames
        hostnames.each do |h|  # hostname
          ProxyPool.instance.add_peer h
        end
        command.run

      rescue CommandLineArgumentError => e
        STDERR.puts "#{@program_name}: #{e.message}"
        puts ""
        usage
        Process.exit 1
      end
    end

  end
end

if $0 == __FILE__
  Castoro::Peer::GroupctlMain.instance.run
end
