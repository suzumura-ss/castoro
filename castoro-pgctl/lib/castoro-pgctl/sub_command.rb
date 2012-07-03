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

module Castoro
  module Peer
    
    module SubCommand
      class Base
        def initialize
          @options = []
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
            x.match( /\A[a-zA-Z0-9_ -]*\Z/ ) or raise CommandLineArgumentError, "Non-alphanumeric letter is not allowed in the command line: #{x}"
            @options.push x
          end
        end

        def title message
          puts "[ #{Time.new.to_s}  #{message} ]"
        end

        def xxxxx &block
          @x = Component.get_peer_group
          Barrier.instance.clients = @x.number_of_components + 1
          if block_given?
            yield
          end
          Barrier.instance.wait  # let slaves start
          Barrier.instance.wait  # wait until slaves finish their tasks
          Exceptions.instance.confirm
        end

        def do_start_daemons
          title "Starting daemons"
          xxxxx { @x.do_start }
          @x.print_start
          Exceptions.instance.confirm
        end

        def do_stop_deamons
          title "Stopping daemons"
          xxxxx { @x.do_stop }
          @x.print_stop
          Exceptions.instance.confirm
        end

        def do_ps
          xxxxx { @x.do_ps }
          Exceptions.instance.confirm
        end

        def do_ps_and_print
          title "Daemon processes"
          do_ps
          @x.print_ps
        end

        def do_status
          xxxxx { @x.do_status }
          Exceptions.instance.confirm
        end

        def do_status_and_print
          title "Status"
          do_ps
          do_status
          @x.print_status
        end

        def turn_autopilot_off
          title "Turning the autopilot off"
          xxxxx { @x.do_auto false }
          @x.print_auto
          @x.verify_auto false
          Exceptions.instance.confirm
        end

        def turn_autopilot_on
          title "Turning the autopilot auto"
          xxxxx { @x.do_auto true }
          @x.print_auto
          @x.verify_auto true
          Exceptions.instance.confirm
        end

        def ascend_the_mode_to mode
          m = ServerStatus.status_code_to_s( mode )
          title "Ascending the mode to #{m}"
          xxxxx { @x.ascend_mode mode }
          @x.print_mode
          Exceptions.instance.confirm
        end

        def descend_the_mode_to mode
          m = ServerStatus.status_code_to_s( mode )
          title "Descending the mode to #{m}"
          xxxxx { @x.descend_mode mode }
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


      class List < Base
        def run
          title "Peer group list"
          i = 0
          Configurations::Peer.instance.StorageGroupsData.each do |x|
            if 0 < x.size
              printf "  G%02d = %s\n", i, x.join(' ')
              i = i + 1
            end
          end
        end
      end


      class Ps < Base
        def run
          do_ps_and_print
        end
      end


      class Status < Base
        def run
          do_status_and_print
        end
      end


      class StartAll < Base
        def run
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


      class Start < Base
        def run
          do_ps_and_print
          SignalHandler.check

          @y = Component.get_the_first_peer
          unless @y.alive?
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
          end

          @x = Component.get_peer_group
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


      class Stop < Base
        def run
          do_ps_and_print
          do_status_and_print
          SignalHandler.check

          @y = Component.get_the_first_peer
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

          @z = Component.get_the_rest_of_peers
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

      class StopAll < Base
        def run
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
    end

  end
end
