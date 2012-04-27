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
    
    PROGRAM_VERSION = "0.0.1.pre1 - 2012-04-26"

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

      def do_start_daemons
        puts "[ #{Time.new.to_s}  Starting daemons ]"
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_start
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_start
      end

      def do_stop_deamons
        puts "[ #{Time.new.to_s}  Stopping daemons ]"
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_stop
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_stop
      end

      def do_ps
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_ps nil
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
      end

      def do_ps_and_print
        puts "[ #{Time.new.to_s}  Daemon processes ]"
        do_ps
        @x.print_ps
      end

      def do_status
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_status @options
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
      end

      def do_status_and_print
        puts "[ #{Time.new.to_s}  Status ]"
        do_status
        @x.print_status
      end

      def turn_autopilot_off
        puts "[ #{Time.new.to_s}  Turning the autopilot off ]"
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.do_auto false
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_auto
      end

      def turn_autopilot_on
        puts "[ #{Time.new.to_s}  Turning the autopilot auto ]"
        @x.do_auto true
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_auto
      end

      def ascend_the_mode_to mode
        m = ServerStatus.status_code_to_s( mode )
        puts "[ #{Time.new.to_s}  Ascending the mode to #{m} ]"
        @x = ProxyPool.instance.get_peer_group
        XBarrier.instance.clients = @x.number_of_targets + 1
        @x.ascend_mode mode
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_mode
      end

      def descend_the_mode_to mode
        m = ServerStatus.status_code_to_s( mode )
        puts "[ #{Time.new.to_s}  Descending the mode to #{m} ]"
        @x.descend_mode mode
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_mode
      end

      def descend_the_mode_to_readonly
        turn_autopilot_off     ; sleep 2
        do_status_and_print    ; sleep 2

        m = @x.mode
        if m.nil? or 30 <= @x.mode
          descend_the_mode_to 25 ; sleep 2  # 25 fin_rep
          do_status_and_print    ; sleep 2
        end

        m = @x.mode
        if m.nil? or 25 <= @x.mode
          descend_the_mode_to 23 ; sleep 2  # 23 rep
          do_status_and_print    ; sleep 2
        end

        m = @x.mode
        if m.nil? or 23 <= @x.mode
          descend_the_mode_to 20 ; sleep 2  # 20 readonly
          do_status_and_print    ; sleep 2
        end
      end

      def descend_the_mode_to_offline
        descend_the_mode_to_readonly

        m = @x.mode
        if m.nil? or 20 <= @x.mode
          descend_the_mode_to 10 ; sleep 2  # 10 offline
          do_status_and_print    ; sleep 2
        end
      end
    end


    class PsSubCommand < SubCommand
      def run
        do_ps_and_print
      end
    end


    class StatusSubCommand < SubCommand
      def run
        do_ps  # obtain the information on the existance of the processes
        do_status_and_print
      end
    end


    class StartAllSubCommand < SubCommand
      def run
        do_ps_and_print

        unless @x.ps_running?
          do_start_daemons       ; sleep 2
          do_ps_and_print        ; sleep 2
        end

        unless @x.mode == 30
          turn_autopilot_off     ; sleep 2
          do_status_and_print    ; sleep 2
          ascend_the_mode_to 30  ; sleep 2
          do_status_and_print    ; sleep 2
          turn_autopilot_on      ; sleep 2
        end

        do_ps_and_print
        do_status_and_print
      end
    end


    class StartSubCommand < SubCommand
      def run
        do_ps_and_print

        @y = ProxyPool.instance.get_the_first_peer
        XBarrier.instance.clients = @y.number_of_targets + 1
        unless @y.ps_running?
          puts "[ #{Time.new.to_s}  Starting the daemon ]"
          @y.do_start
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @y.print_start
          sleep 2
          do_ps_and_print
        end

        @x = ProxyPool.instance.get_peer_group
        unless @x.mode == 30
          turn_autopilot_off     ; sleep 2
          do_status_and_print    ; sleep 2
          ascend_the_mode_to 30  ; sleep 2
          do_status_and_print    ; sleep 2
          turn_autopilot_on      ; sleep 2
        end

        do_ps_and_print
        do_status_and_print
      end
    end


    class StopSubCommand < SubCommand
      def run
        do_ps_and_print
        do_status_and_print

        @y = ProxyPool.instance.get_the_first_peer
        if false == @y.ps_running?
          puts "The deamons on the peer have already stopped."
          return
        end

        descend_the_mode_to_readonly

        mode = 10
        m = ServerStatus.status_code_to_s( mode )
        puts "[ #{Time.new.to_s}  Descending the mode to #{m} ]"
        @y = ProxyPool.instance.get_the_first_peer
        XBarrier.instance.clients = @y.number_of_targets + 1
        @y.descend_mode 10  # 10 offline
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @y.print_mode
        sleep 2

        do_status_and_print

        puts "[ #{Time.new.to_s}  Stopping the daemon ]"
        @y = ProxyPool.instance.get_the_first_peer
        XBarrier.instance.clients = @y.number_of_targets + 1
        @y.do_stop
        XBarrier.instance.wait  # let slaves start
        XBarrier.instance.wait  # wait until slaves finish their tasks
        @x.print_stop
        sleep 2

        do_ps_and_print

        @z = ProxyPool.instance.get_the_rest_of_peers
        XBarrier.instance.clients = @z.number_of_targets + 1
        if 0 < @z.number_of_targets
          puts "[ #{Time.new.to_s}  Turning the autopilot auto ]"
          @z.do_auto true
          XBarrier.instance.wait  # let slaves start
          XBarrier.instance.wait  # wait until slaves finish their tasks
          @x.print_auto
          sleep 2
        end

        do_ps_and_print
        do_status_and_print
      end
    end

    class StopAllSubCommand < SubCommand
      def run
        do_ps_and_print
        do_status_and_print

        if false == @x.ps_running?
          puts "All deamons on every peer have already stopped."
          return
        end

        descend_the_mode_to_offline
        do_stop_deamons
        sleep 2

        do_ps_and_print
        do_status_and_print
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
              [ '--version',             '-V', GetoptLong::NO_ARGUMENT ],
              [ '--configuration-file',  '-c', GetoptLong::REQUIRED_ARGUMENT ],
              )

        x.each do |opt, arg|
          case opt
          when '--help'
            usage
            Process.exit 0
          when '--debug'
            $DEBUG = true
          when '--version'
            puts "#{@program_name} - Version #{PROGRAM_VERSION}"
            Process.exit 0
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
        when 'start'    ; StartSubCommand.new
        when 'stop'     ; StopSubCommand.new
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
        x = @program_name
        puts "usage: #{x} [global options...] sub-command [options...] [parameters...] [hostnames..]"
        puts ""
        puts "  global options:"
        puts "   -h, --help     prints this help message and exit."
        puts "   -d, --debug    this command runs with debug messages being printed."
        puts "   -V, --version  shows a version number of this command."
        puts "   -c file, --configuration-file=file  specifies a configuration file."
        puts "                  default: /etc/castoro/groupctl.conf"
        puts ""
        puts "  sub commands:"
        puts "   ps         lists the deamon processes in a 'ps -ef' format"
        puts "   status     shows the status of the deamon processes on the every host"
        puts "   startall   starts deamon processes on every host of the peer group"
        puts "   stopall    stops  daemon processes on every host of the peer group"
        puts "   start      starts daemon processes on the only target peer host"
        puts "   stop       stops  daemon processes on the only target peer host"
        puts ""
        puts " examples:"
        puts "   #{x} status peer01 peer02 peer03"
        puts "        shows the status of peer01, peer02, and peer03."
        puts ""
        puts "   #{x} stop peer01 peer02 peer03"
        puts "        peer01 will be stopped."
        puts "        peer02 and peer03 will be readonly."
        puts ""
        puts "   #{x} start peer01 peer02 peer03"
        puts "        peer01 will be started, then"
        puts "        peer01, peer02, and peer03 will be online."
        puts ""
        puts "   #{x} stopall peer01 peer02 peer03"
        puts "        peer01 peer02, and peer03 will be stopped."
        puts ""
        puts "   #{x} startall peer01 peer02 peer03"
        puts "        peer01 peer02, and peer03 will be started, then be online."
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
