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

    class PeerComponent
      def initialize hostname
        @hostname = hostname
        @targets = ProxyPool.instance.entries[ hostname ]
      end

      def number_of_targets
        @targets.size
      end

      def do_ps
        @targets.each do |t, x|  # target type, proxy object
          x.do_ps
        end
      end

      def print_ps
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', @targets.values[0].ps_header
        @targets.map do |t, x|
          if x.ps_error
            printf f, h, t, x.ps_error
          else
            if x.ps_stdout
              if 0 < x.ps_stdout.size
                x.ps_stdout.each do |y|
                  printf f, h, t, y
                end
              else
                printf f, h, t, ''  # grep pattern did not match
              end
            else
              printf f, h, t, '(error occured)'
            end
          end
        end
        puts ''
      end

      def ps_running?
        r = nil
        @targets.each do |t, x|  # target type, proxy object
          x = x.ps_running
          x.nil? and return nil
          if r.nil?
            r = x
          elsif r != x
            return nil
          end
        end
        r
      end

      def print_ps_printf hostname, type, message
        h = hostname || 'HOSTNAME'
        t = type || 'DAEMON'
        printf "%-14s%-14s%s\n", h, t, message
      end

      def do_status
        @targets.each do |t, x|  # target type, proxy object
          x.do_status
        end
      end

      def print_status
        f = "%-14s%-14s%-14s%-14s%-14s%-14s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'ACTIVITY', 'MODE', 'AUTOPILOT', 'DEBUG'
        @targets.map do |t, x|
          r = x.ps_error ? "(#{x.ps_error})" : (x.ps_running.nil? ? 'unknown' : (x.ps_running ? 'running' : 'stopped'))
          if x.status_error
            if x.status_error.match( /Connection refused/ )
              printf f, h, t, r, nil, nil, nil
            else
              printf f, h, t, r, x.status_error, nil, nil
            end
          else
            m = x.status_mode ? ServerStatus.status_code_to_s( x.status_mode ) : ''
            a = x.status_auto.nil? ? '' : ( x.status_auto ? 'auto' : 'off' )
            d = x.status_debug.nil? ? '' : ( x.status_debug ? 'on' : 'off' )
            printf f, h, t, r, m, a, d
          end
        end
        puts ''
      end

      def do_start
        @targets.each do |t, x|
          x.do_start
        end
      end

      def print_start
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.start_error
            printf f, h, t, x.start_error
          else
            printf f, h, t, x.start_message
          end
        end
        puts ''
      end

      def do_stop
        @targets.each do |t, x|
          x.do_stop
        end
      end

      def print_stop
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.stop_error
            printf f, h, t, x.stop_error
          else
            printf f, h, t, x.stop_message
          end
        end
        puts ''
      end

      def do_mode mode
        @targets.each do |t, x|
          x.do_mode mode
        end
      end

      def print_mode
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.mode_error
            printf f, h, t, x.mode_error
          else
            printf f, h, t, x.mode_message
          end
        end
        puts ''
      end

      def ascend_mode mode
        @targets.each do |t, x|
          x.ascend_mode mode
        end
      end

      def descend_mode mode
        @targets.each do |t, x|
          x.descend_mode mode
        end
      end

      def mode
        r = nil
        @targets.each do |t, x|
          if x.is_a? CxxxdProxy
            m = x.status_mode
            m.nil? and return nil
            if r.nil?
              r = m
            else
              r == m or return nil
            end
          end
        end
        r
      end

      def do_auto auto
        @targets.each do |t, x|
          x.do_auto auto
        end
      end

      def print_auto
        f = "%-14s%-14s%s\n"  # format
        h = @hostname
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        @targets.map do |t, x|
          if x.auto_error
            printf f, h, t, x.auto_error
          else
            printf f, h, t, x.auto_message
          end
        end
        puts ''
      end
    end

  end
end
