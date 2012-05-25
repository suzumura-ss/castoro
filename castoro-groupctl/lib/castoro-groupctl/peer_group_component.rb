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

require 'castoro-groupctl/proxy'

module Castoro
  module Peer

    class PeerGroupComponent
      def self.create_components hostname
        { :cmond        => CmondProxy.new( hostname ),
          :cpeerd       => CpeerdProxy.new( hostname ),
          :crepd        => CrepdProxy.new( hostname ),
          :manipulatord => ManipulatordProxy.new( hostname ) }
      end

      def initialize entries
        @entries = entries
      end

      def work_on_every_component linefeed, &block
        @entries.each do |h, c|  # hostname, components
          c.each do |t, x|  # component type, proxy object
            yield h, t, x  # hostname, component type, proxy object
          end
          puts '' if linefeed
        end
      end

      def work_on_every_component_simple &block
        @entries.values.each do |c|  # components
          c.values.each do |x|  # proxy object
            yield x  # proxy object
          end
        end
      end

      def number_of_components
        n = 0  # number
        work_on_every_component_simple { |x| n = n + 1 }
        n
      end

      def do_ps
        work_on_every_component_simple { |x| x.do_ps }  # proxy object
      end

      def obtain_ps_header
        work_on_every_component_simple do |x|
          return x.ps.header if x.ps.header and x.ps.header != ''
        end
        nil
      end

      def print_ps
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', obtain_ps_header
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          if ( e = x.ps.exception || x.ps.error )
            printf f, h, t, e
          else
            if x.ps.stdout
              if 0 < x.ps.stdout.size
                x.ps.stdout.each do |y|
                  printf f, h, t, y
                end
              else
                printf f, h, t, ''  # grep pattern did not match
              end
            else
              printf f, h, t, '(unknown error occured)'
            end
          end
        end
      end

      def alive?
        r = nil  # return value
        work_on_every_component_simple do |x|  # proxy object
          a = x.ps.alive
          a.nil? and return nil
          if r.nil?
            r = a
          elsif r != a
            return nil
          end
        end
        r
      end

      def do_start
        work_on_every_component_simple do |x|  # proxy object
          if @starting_daemon = ( x.ps.alive == 1 )
            x.do_start
          else
            x.do_dummy
          end
        end
      end

      def print_start
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          m = @starting_daemon ? ( x.start.exception || x.start.error || x.start.message ) : '(Did nothing because the daemon process is running.)'
          printf f, h, t, m
        end
      end

      def do_stop
        work_on_every_component_simple do |x|  # proxy object
          if @stopping_daemon = ( x.ps.alive == 0 )
            x.do_stop
          else
            x.do_dummy
          end
        end
      end

      def print_stop
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          m = @stopping_daemon ? ( x.stop.exception || x.stop.error || x.stop.message ) : '(Did nothing because the daemon process has stopped.)'
          printf f, h, t, m
        end
      end

      def do_status
        work_on_every_component_simple do |x|  # proxy object
          x.do_status
        end
      end

      def print_status
        f = "%-14s%-14s%-14s%-14s%-14s%-14s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'ACTIVITY', 'MODE', 'AUTOPILOT', 'DEBUG'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          e = x.ps.exception || x.ps.error
          if e
            printf f, h, t, e, nil, nil, nil
          else
            r = x.ps.status
            s = x.status
            e = s.exception || s.error
            if e
              m = e || ( s.error.match( /Connection refused/ ) ? nil : s.error )
              printf f, h, t, r, m, nil, nil
            else
              m = s.mode ? ServerStatus.status_code_to_s( s.mode ) : ''
              a = s.auto.nil? ? '' : ( s.auto ? 'auto' : 'off' )
              d = s.debug.nil? ? '' : ( s.debug ? 'on' : 'off' )
              printf f, h, t, r, m, a, d
            end
          end
        end
      end

      def do_mode mode
        @peers.each { |x| x.do_mode mode }
      end

      def print_mode
        @peers.each { |x| x.print_mode }
      end

      def ascend_mode mode
        @peers.each { |x| x.ascend_mode mode }
      end

      def descend_mode mode
        @peers.each { |x| x.descend_mode mode }
      end

      def mode
        r = nil
        @peers.each do |x|
          m = x.mode
          m.nil? and return nil
          if r.nil?
            r = m
          else
            r == m or return nil
          end
        end
        r
      end

      def do_auto auto
        @peers.each { |x| x.do_auto auto }
      end

      def print_auto
        @peers.each { |x| x.print_auto }
      end
    end

  end
end
