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

require 'socket'
require 'castoro-pgctl/barrier'
require 'castoro-pgctl/component'
require 'castoro-pgctl/signal_handler'
require 'castoro-pgctl/exceptions'
require 'castoro-pgctl/configurations_peer'
require 'castoro-pgctl/password'

module Castoro
  module Peer
    
    module SubCommand
      module PsModule
        def do_ps
          dispatch { @x.do_ps }
          Exceptions.instance.confirm
        end

        def do_ps_and_print
          title "Daemon processes"
          do_ps
          @x.print_ps
        end
      end


      module StatusModule
        def do_status
          dispatch { @x.do_status }
          Exceptions.instance.confirm
        end

        def do_status_and_print
          title "Status"
          do_ps
          do_status
          @x.print_status
        end
      end


      module StartStopModule
        def do_start_daemons
          title "Starting daemons"
          dispatch { @x.do_start }
          @x.print_start
          Exceptions.instance.confirm
        end

        def do_stop_deamons
          title "Stopping daemons"
          dispatch { @x.do_stop }
          @x.print_stop
          Exceptions.instance.confirm
        end
      end


      module AutopilotModule
        def turn_autopilot_off
          title "Turning the autopilot off"
          dispatch { @x.do_auto false }
          @x.print_auto
          @x.verify_auto false
          Exceptions.instance.confirm
        end

        def turn_autopilot_on
          title "Turning the autopilot auto"
          dispatch { @x.do_auto true }
          @x.print_auto
          @x.verify_auto true
          Exceptions.instance.confirm
        end
      end


      module ModeModule
        def ascend_the_mode_to mode
          m = ServerStatus.status_code_to_s( mode )
          title "Ascending the mode to #{m}"
          dispatch { @x.ascend_mode mode }
          @x.print_mode
          Exceptions.instance.confirm
        end

        def descend_the_mode_to mode
          m = ServerStatus.status_code_to_s( mode )
          title "Descending the mode to #{m}"
          dispatch { @x.descend_mode mode }
          @x.print_mode
          Exceptions.instance.confirm
        end

        def descend_the_mode_to_readonly
          turn_autopilot_off     ; sleep 2
          do_status_and_print
          SignalHandler.check    ; sleep 2

          m = @x.mode
          if m.nil? or 30 <= m
            descend_the_mode_to 25 ; sleep 2  # 25 fin_rep
            do_status_and_print
            @x.verify_mode_less_or_equal 25
            SignalHandler.check ; sleep 2
          end

          m = @x.mode
          if m.nil? or 25 <= m
            descend_the_mode_to 23 ; sleep 2  # 23 rep
            do_status_and_print
            @x.verify_mode_less_or_equal 23
            SignalHandler.check ; sleep 2
          end

          m = @x.mode
          if m.nil? or 23 <= m
            descend_the_mode_to 20 ; sleep 2  # 20 readonly
            do_status_and_print
            @x.verify_mode_less_or_equal 20 ; sleep 2
            SignalHandler.check ; sleep 2
          end
        end

        def descend_the_mode_to_offline
          descend_the_mode_to_readonly

          m = @x.mode
          if m.nil? or 20 <= m
            descend_the_mode_to 10 ; sleep 2  # 10 offline
            do_status_and_print
            @x.verify_mode_less_or_equal 10
            SignalHandler.check ; sleep 2
          end
        end
      end


      class Base
        include PsModule
        include StatusModule
        include StartStopModule
        include AutopilotModule
        include ModeModule

        def initialize
          @options = []
          @hosts = []
          @groups = []
          parse_parameters          
        end

        def title message
          puts "[ #{Time.new.to_s}  #{message} ]"
        end

        def dispatch &block
          Barrier.instance.clients = @x.number_of_components + 1
          if block_given?
            yield
          end
          Barrier.instance.wait  # let slaves start
          Barrier.instance.wait  # wait until slaves finish their tasks
          Exceptions.instance.confirm
        end

        private

        def determine_type x
          unless x.match( /\A[a-zA-Z0-9_ -]*\Z/ )
            raise CommandLineArgumentError, "Non-alphanumeric letter is not allowed: #{x}"
          end

          if Configurations::Peer.instance.StorageGroups.has_key? x
            return :group  # it is a group name
          elsif x.match( /\A-/ )
            return :option
          else
            begin
              Socket.gethostbyname x  # determine if the parameter is a hostname
              return :host            # it is a hostname
            rescue SocketError => e
              # intentionally ignored. it is not a hostname
            end
          end
          nil
        end

        def parse_parameters
          while ( x = ARGV.shift )
            case determine_type x

            when :group
              @groups.push x
              while ( x = ARGV.shift )
                case determine_type x
                when :group ; @groups.push x
                else ; raise CommandLineArgumentError, "Parameters should not mix a group name and host name: #{x}"
                end
              end
                  
            when :host
              @hosts.push x
              while ( x = ARGV.shift )
                case determine_type x
                when :host ; @hosts.push x
                else ; raise CommandLineArgumentError, "Parameters should not mix a group name and host name: #{x}"
                end
              end

            when :option
              @options.push x

            else
              raise CommandLineArgumentError, "Parameters should be either option, host name, or group name: #{x}"
            end
          end
        end
      end


      # list, ps, status
      class AnynameAccepted < Base
        def initialize
          super

          @hosts.each do |h|  # host name
            Component.add_peer h
          end

          @groups.each do |g|  # group name
            Configurations::Peer.instance.StorageGroups[g].each do |h|  # host name
              Component.add_peer h
            end
          end

          @x = Component.get_peer_group
        end
      end


      class NoNameAccepted < Base
        def initialize
          super
          unless 0 == @hosts.size && 0 == @groups.size
            raise CommandLineArgumentError, "No parameter is required"
          end
        end
      end


      class AtLeastOneNameRequired < AnynameAccepted
        def initialize
          super
          if 0 == @hosts.size && 0 == @groups.size
            raise CommandLineArgumentError, "Parameters should have at least one host or group name"
          end
        end
      end

      # none
      class HostnameOriented < AnynameAccepted
        def initialize
          super
          0 < @hosts.size   or raise CommandLineArgumentError, "Parameters should be a single host name or a list of host names"
          0 == @groups.size or raise CommandLineArgumentError, "Parameters should not include group names"
        end
      end


      # gstart, gstop
      class GroupnameOriented < AnynameAccepted
        def initialize
          super
          0 < @groups.size or raise CommandLineArgumentError, "Parameters should be a single group name or a list of group names"
          0 == @hosts.size or raise CommandLineArgumentError, "Parameters should not include host names"
        end
      end


      # start, stop
      class TargethostOriented < HostnameOriented
        def initialize
          super

          y = []  # the target hosts
          z = []  # the rest of hosts

          @hosts.each do |h|
            Configurations::Peer.instance.StorageGroups.each do |name, hosts|
              if hosts.include? h
                y.include?( h ) and raise CommandLineArgumentError, "the hostname is given twice: #{h}"
                y.push h
                d = hosts.dup
                d.delete h
                ( z & d ).size == 0 or raise CommandLineArgumentError, "Hostnames overwrap: #{z.inspect} #{d.inspect}"
                d.each do |s|  # host name
                  Component.add_peer s
                  z.push s
                end
              end
            end
          end

          x = y + z   # all hosts
          @x = Component.get_peerlist x
          @y = Component.get_peerlist y
          @z = Component.get_peerlist z
        end
      end


      class List < AnynameAccepted
        def run
          title "Peer group list"
          @groups.each do |x|
            printf "  %s = %s\n", x, Configurations::Peer.instance.StorageGroups[x].join(' ')
          end

          @hosts.each do |x|
            Configurations::Peer.instance.StorageGroups.each do |name, hosts|
              printf "  %s = %s\n", name, hosts.join(' ') if hosts.include? x
            end
          end
            
          if @groups.size == 0 && @hosts.size == 0
            Configurations::Peer.instance.StorageGroups.each do |name, hosts|
              printf "  %s = %s\n", name, hosts.join(' ')
            end
          end
        end
      end


      class Ps < AtLeastOneNameRequired
        def run
          do_ps_and_print
        end
      end


      class Status < AtLeastOneNameRequired
        def run
          do_status_and_print
        end
      end


      class Passwd < NoNameAccepted
        def run
          Password.instance.change
        end
      end


      class Gstart < GroupnameOriented
        def run
          if 0 == @x.size
            raise Failure::NoGroupSpecified, "No peer group is specified."
          end

          do_ps_and_print
          SignalHandler.check

          unless @x.alive?
            do_start_daemons       ; sleep 2
            do_ps_and_print
            @x.verify_start        ; sleep 2
            SignalHandler.check
          end

          do_status_and_print
          unless @x.mode == 30
            turn_autopilot_off     ; sleep 2
            do_status_and_print    ; sleep 2
            SignalHandler.check

            ascend_the_mode_to 30  ; sleep 2
            do_status_and_print
            @x.verify_mode_more_or_equal 30 ; sleep 2
            SignalHandler.check

            turn_autopilot_on      ; sleep 2
          end

          do_ps_and_print
          do_status_and_print
          @x.verify_mode 30
          sleep 2

          do_status_and_print
          @x.verify_mode 30
        end
      end


      class Start < TargethostOriented
        def run
          do_ps_and_print
          SignalHandler.check

          unless @z.alive?
            raise Failure::OtherHostsNotRunning, "Some of other hosts in the same peer group are not running."
          end

          if @y.alive?
            puts "Deamon processes of the specified host are already running."
            return
          end

          title "Starting the daemon"
          Barrier.instance.clients = @y.number_of_components + 1
          @y.do_start
          Barrier.instance.wait  # let slaves start
          Barrier.instance.wait  # wait until slaves finish their tasks
          @y.print_start
          Exceptions.instance.confirm
          sleep 2
          do_ps_and_print
          @y.verify_start
          SignalHandler.check

          do_status_and_print    ; sleep 2
          SignalHandler.check

          unless @x.mode == 30
            turn_autopilot_off     ; sleep 2
            do_status_and_print    ; sleep 2
            SignalHandler.check

            ascend_the_mode_to 30  ; sleep 2
            do_status_and_print
            SignalHandler.check

            @x.verify_mode_more_or_equal 30 ; sleep 2
            turn_autopilot_on      ; sleep 2
          end

          do_ps_and_print
          do_status_and_print
          @x.verify_mode 30
          sleep 2

          do_status_and_print
          @x.verify_mode 30
        end
      end


      class Wakeup < HostnameOriented
        def run
          do_ps_and_print
          SignalHandler.check

          if @x.alive?
            puts "The deamons on the peer have already started."
            return
          end

          do_start_daemons
          SignalHandler.check
          sleep 2
          do_ps_and_print
          @x.verify_start
        end
      end


      class Stop < TargethostOriented
        def run
          do_ps_and_print
          do_status_and_print
          SignalHandler.check

          if false == @y.alive?
            puts "The deamons on the peer have already stopped."
            return
          end

          descend_the_mode_to_readonly

          mode = 10
          m = ServerStatus.status_code_to_s( mode )
          title "Descending the mode to #{m}"
          @y = Component.get_the_first_peer
          Barrier.instance.clients = @y.number_of_components + 1
          @y.descend_mode 10  # 10 offline
          Barrier.instance.wait  # let slaves start
          Barrier.instance.wait  # wait until slaves finish their tasks
          @y.print_mode
          Exceptions.instance.confirm

          do_status_and_print
          @y.verify_mode_less_or_equal 10
          SignalHandler.check
          sleep 2

          title "Stopping the daemon"
          @y = Component.get_the_first_peer
          Barrier.instance.clients = @y.number_of_components + 1
          @y.do_stop
          Barrier.instance.wait  # let slaves start
          Barrier.instance.wait  # wait until slaves finish their tasks
          @y.print_stop
          Exceptions.instance.confirm
          sleep 2

          do_ps_and_print
          SignalHandler.check

          Barrier.instance.clients = @z.number_of_components + 1
          if 0 < @z.number_of_components
            title "Turning the autopilot auto"
            @z.do_auto true
            Barrier.instance.wait  # let slaves start
            Barrier.instance.wait  # wait until slaves finish their tasks
            @z.print_auto
            @z.verify_auto true
            Exceptions.instance.confirm
            sleep 2

            do_ps_and_print
            SignalHandler.check
          end

          do_status_and_print
          @y.verify_stop
          @z.verify_alive
          @z.verify_mode 20
        end
      end

      class Gstop < GroupnameOriented
        def run
          if 0 == @x.size
            raise Failure::NoGroupSpecified, "No peer group is specified."
          end

          do_ps_and_print
          do_status_and_print
          SignalHandler.check

          if false == @x.alive?
            puts "All deamons on every peer have already stopped."
            return
          end

          descend_the_mode_to_offline
          do_stop_deamons
          SignalHandler.check
          sleep 2

          do_ps_and_print
          do_status_and_print
          @x.verify_stop
        end
      end


      class Kill < HostnameOriented
        def run
          do_ps_and_print
          do_status_and_print
          SignalHandler.check

          if false == @x.alive?
            puts "The deamons on the peer have already stopped."
            return
          end

          do_stop_deamons
          SignalHandler.check
          sleep 2

          do_ps_and_print
          do_status_and_print
          @x.verify_stop
        end
      end
    end

  end
end
