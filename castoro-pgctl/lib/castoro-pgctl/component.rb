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

require 'castoro-pgctl/proxy'
require 'castoro-pgctl/exceptions'

module Castoro
  module Peer

    class Component
      @@pool = {}

      def self.add_peer hostname
        @@pool.has_key? hostname and raise CommandLineArgumentError, "Hostname #{hostname} is given twice."

        @@pool[ hostname ] = 
          [ Proxy::Cmond.new( hostname ),
            Proxy::Cpeerd.new( hostname ),
            Proxy::Crepd.new( hostname ),
            Proxy::Manipulatord.new( hostname ) ]
      end

      def self.get_peer hostname
        self.new( { hostname => @@pool[ hostname ] } )
      end

      def self.get_the_first_peer
        get_peer @@pool.keys[0]
      end

      def self.get_the_rest_of_peers
        x = @@pool.dup
        x.delete( x.keys[0] )
        self.new x
      end

      def self.get_peer_group
        self.new @@pool
      end

      def self.get_peerlist hostnames
        entries = Hash.new.tap do |x|
          hostnames.each do |h|
            x[ h ] = @@pool[ h ]
          end
        end
        self.new entries
      end

      def initialize entries
        @entries = entries
      end

      def size
        @entries.size
      end

      def work_on_every_component linefeed = false, &block
        @entries.each do |h, c|  # hostname, components
          n = 0
          c.each do |x|  # proxy object
            t = x.target   # component type
            r = yield h, t, x  # hostname, component type, proxy object
            n = n + 1 if not r.nil? and r
          end
          puts '' if linefeed && 0 < n
        end
      end

      def work_on_every_component_simple &block
        @entries.values.each do |c|  # components
          c.each do |x|  # proxy object
            yield x  # proxy object
          end
        end
      end

      def number_of_components
        n = 0  # number
        work_on_every_component_simple { |x| n = n + 1 }
        n
      end

      def do_date
        work_on_every_component_simple { |x| x.do_date }  # proxy object
      end

      def print_date_printf h, s
        f = "%-14s%s\n"  # format
        s = sprintf f, h, s
        print s.sub( / +\Z/, "" )
      end

      def print_date
        print_date_printf 'HOSTNAME', 'DATE'
        work_on_every_component( false ) do |h, t, x|  # hostname, component type, proxy object
          if t == :cmond
            if ( e = x.date.exception || x.date.error )
              print_date_printf h, e
            else
              if x.date.tv_sec and x.date.tv_usec
                date = Time.at x.date.tv_sec, x.date.tv_usec
                print_date_printf h, date.to_s
              else
                print_date_printf h, '(unknown error occured)'
              end
            end
            true
          end
        end
        print "\n"
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

      def print_ps_printf h, t, s
        f = "%-14s%-14s%s\n"  # format
        s = sprintf f, h, t, s
        print s.sub( / +\Z/, "" )
      end

      def print_ps
        print_ps_printf 'HOSTNAME', 'DAEMON', obtain_ps_header
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          if ( e = x.ps.exception || x.ps.error )
            print_ps_printf h, t, e
          else
            if x.ps.stdout
              if 0 < x.ps.stdout.size
                x.ps.stdout.each do |y|
                  print_ps_printf h, t, y
                end
              else
                print_ps_printf h, t, ''  # grep pattern did not match
              end
            else
              print_ps_printf h, t, '(unknown error occured)'
            end
          end
          true
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
          if x.flag = ( x.ps.alive == false )
            x.do_start
          else
            x.do_dummy
          end
        end
      end

      def print_plan_for_start
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'PLANS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          if x.flag = ( x.ps.alive == false )
            printf f, h, t, "The daemon process will be started."
            true
          else
            false
          end
        end
      end

      def print_start
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          m = x.flag ? ( x.start.exception || x.start.error || x.start.message ) : '(Did nothing because the daemon process is running.)'
          printf f, h, t, m
          true
        end
      end

      def verify_start
        z = []
        work_on_every_component do |h, t, x|  # hostname, component type, proxy object
          z.push "#{x.ps.exception}: #{h} #{t}" if x.ps.exception
          z.push "#{x.ps.error}: #{h} #{t}"     if x.ps.error
          z.push "#{'%-6s' % t} on #{h} should have started." if x.ps.alive != true
        end
        raise Failure::Start, z.join("\n") if 0 < z.size
      end

      def verify_alive
        z = []
        work_on_every_component do |h, t, x|  # hostname, component type, proxy object
          z.push "#{x.ps.exception}: #{h} #{t}" if x.ps.exception
          z.push "#{x.ps.error}: #{h} #{t}"     if x.ps.error
          z.push "#{'%-6s' % t} on #{h} should be running." if x.ps.alive != true
        end
        raise Failure::Alive, z.join("\n") if 0 < z.size
      end

      def do_stop
        work_on_every_component_simple do |x|  # proxy object
          if x.flag = ( x.ps.alive == true )
            x.do_stop
          else
            x.do_dummy
          end
        end
      end

      def print_plan_for_stop
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'PLANS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          if x.flag = ( x.ps.alive == true )
            printf f, h, t, "The daemon process will be stopped."
            true
          else
            false
          end
        end
      end

      def print_stop
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          m = x.flag ? ( x.stop.exception || x.stop.error || x.stop.message ) : '(Did nothing because the daemon process has stopped.)'
          printf f, h, t, m
          true
        end
      end

      def verify_stop
        z = []
        work_on_every_component do |h, t, x|  # hostname, component type, proxy object
          z.push "#{x.ps.exception}: #{h} #{t}" if x.ps.exception
          z.push "#{x.ps.error}: #{h} #{t}"     if x.ps.error
          z.push "#{'%-6s' % t} on #{h} should have stopped." if x.ps.alive != false
        end
        raise Failure::Stop, z.join("\n") if 0 < z.size
      end

      def do_status
        work_on_every_component_simple do |x|  # proxy object
          x.do_status
        end
      end

      def print_status_printf h, t, r, m, a, d
        f = "%-14s%-14s%-14s%-14s%-14s%-14s\n"  # format
        s = sprintf f, h, t, r, m, a, d
        print s.sub( / +\Z/, "" )
      end

      def print_status
        print_status_printf 'HOSTNAME', 'DAEMON', 'ACTIVITY', 'MODE', 'AUTOPILOT', 'DEBUG'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          e = x.ps.exception || x.ps.error
          if e
            print_status_printf h, t, e, nil, nil, nil
          else
            r = x.ps.status
            s = x.status
            e = s.exception || s.error
            if e
              m = e || ( s.error.match( /Connection refused/ ) ? '(Connection refused)' : s.error )
              print_status_printf h, t, r, m, nil, nil
            else
              m = s.mode ? ServerStatus.status_code_to_s( s.mode ) : ''
              a = s.auto.nil? ? '' : ( s.auto ? 'auto' : 'off' )
              d = s.debug.nil? ? '' : ( s.debug ? 'on' : 'off' )
              print_status_printf h, t, r, m, a, d
            end
          end
          true
        end
      end

      def do_mode mode
        work_on_every_component_simple do |x|  # proxy object
          x.do_mode mode
        end
      end

      def print_mode
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          e = x.mode.exception || x.mode.error
          if e
            printf f, h, t, e
          else
            printf f, h, t, x.mode.message
          end
          true
        end
      end

      def ascend_mode mode
        work_on_every_component_simple do |x|  # proxy object
          x.ascend_mode mode
        end
      end

      def print_plan_for_ascending_the_mode_to mode
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'PLANS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          unless t == :manipulatord
            s = x.status
            m = s.mode ? ServerStatus.status_code_to_s( s.mode ) : 'unknown'
            n = ServerStatus.status_code_to_s( mode )
            unless m == n
              printf f, h, t, "The mode will be raised from #{m} to #{n}."
              true
            else
              false
            end
          else
            false
          end
        end
      end

      def descend_mode mode
        work_on_every_component_simple do |x|  # proxy object
          x.descend_mode mode
        end
      end

      def print_plan_for_descending_the_mode_to mode
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'PLANS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
          unless t == :manipulatord
            s = x.status
            m = s.mode ? ServerStatus.status_code_to_s( s.mode ) : 'unknown'
            n = ServerStatus.status_code_to_s( mode )
            unless m == n
              printf f, h, t, "The mode will be lowered from #{m} to #{n}."
              true
            else
              false
            end
          else
            false
          end
        end
      end

      def mode
        r = nil
        work_on_every_component_simple do |x|  # proxy object
          if x.has_mode?
            m = x.status.mode
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

      def _verify_mode mode, s, &block
        z = []
        work_on_every_component do |h, t, x|  # hostname, component type, proxy object
          if x.has_mode?
            unless yield( x.status.mode, mode )
              a = ServerStatus.status_code_to_s x.status.mode  # actual mode
              m = ServerStatus.status_code_to_s mode           # mode expected
              z.push "The mode of #{'%-6s' % t} on #{h} should be #{s}#{m}, but it is currently #{a}."
            end
          end
        end
        raise Failure::Mode, z.join("\n") if 0 < z.size
      end

      def verify_mode mode
        _verify_mode( mode, "" ) { |a, m| a == m }
      end

      def verify_mode_more_or_equal mode
        _verify_mode( mode, "more than or equal to " ) { |a, m| ! a.nil? && a >= m }
      end

      def verify_mode_less_or_equal mode
        _verify_mode( mode, "less than or equal to " ) { |a, m| ! a.nil? && a <= m }
      end

      def do_auto auto
        work_on_every_component_simple do |x|  # proxy object
          x.do_auto auto
        end
      end

      def print_auto
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', 'RESULTS'
        work_on_every_component( true ) do |h, t, x|  # hostname, component type, proxy object
           e = x.auto.exception || x.auto.error
          if e
            printf f, h, t, e
          else
            printf f, h, t, x.auto.message
          end
          true
        end
      end

      def auto
        r = nil
        work_on_every_component_simple do |x|  # proxy object
          if x.has_auto?
            a = x.status.auto
            a.nil? and return nil
            if r.nil?
              r = a
            else
              r == a or return nil
            end
          end
        end
        r
      end

      def verify_auto auto
        z = []
        work_on_every_component do |h, t, x|  # hostname, component type, proxy object
          if x.has_auto?
            z.push "#{x.auto.exception}: #{h} #{t}" if x.auto.exception
            z.push "#{x.auto.error}: #{h} #{t}"     if x.auto.error
            unless x.auto.auto == auto
              a = auto ? 'auto' : 'off'
              z.push "Autopilot of #{'%-6s' % t} on #{h} should be #{a}, but it is currently #{x.auto.message}"
            end
          end
        end
        raise Failure::Auto, z.join("\n") if 0 < z.size
      end

      def do_remains type, threshold
        work_on_every_component_simple do |x|  # proxy object
          x.do_remains type, threshold
        end
      end

      def print_remains_printf h, i, j, k, m, n
        f = "%-14s %14d%7d %17d%7d  %18d\n"  # format
        s = sprintf f, h, i, j, k, m, n
        print s.sub( / +\Z/, "" )
      end

      def print_remains
        print "HOSTNAME      UPLOADING(TOTAL ACTIVE)  RECEIVING(TOTAL ACTIVE)  REPLICATING(TOTAL)\n"
        i, j, k, m, n = nil, nil, nil, nil, nil
        work_on_every_component( false ) do |h, t, x|  # hostname, component type, proxy object
          if t == :cmond  # Todo. This is silly.

            if ( a = x.remains[ :uploading ] )
              if ( e = a.exception || a.error )
                print_remains_printf h, e, '', '', '', ''
              else
                i = a.inactive + a.active
                j = a.active
              end
            end

            if ( a = x.remains[ :receiving ] )
              if ( e = a.exception || a.error )
                print_remains_printf h, e, '', '', '', ''
              else
                k = a.inactive + a.active
                m = a.active
              end
            end

            if ( a = x.remains[ :sending ] )
              if ( e = a.exception || a.error )
                print_remains_printf h, e, '', '', '', ''
              else
                n = a.inactive + a.active
              end
            end

            if i && j && k && m && n
              print_remains_printf h, i, j, k, m, n
              i, j, k, m, n = nil, nil, nil, nil, nil
            end
          end
          true
        end
        print "\n"
      end

      def print_remains_uploading_printf h, i, j
        f = "%-14s %14d%7d\n"  # format
        s = sprintf f, h, i, j
        print s.sub( / +\Z/, "" )
      end

      def print_remains_uploading
        print "HOSTNAME      UPLOADING(TOTAL ACTIVE)\n"
        work_on_every_component( false ) do |h, t, x|  # hostname, component type, proxy object
          if t == :cmond  # Todo. This is silly.
            if ( a = x.remains[ :uploading ] )
              if ( e = a.exception || a.error )
                print_remains_uploading_printf h, e, ''
              else
                i = a.inactive + a.active
                j = a.active
                print_remains_uploading_printf h, i, j
              end
            end
          end
          true
        end
        print "\n"
      end

      def remains_uploading_active
        count = 0
        work_on_every_component( false ) do |h, t, x|  # hostname, component type, proxy object
          if t == :cmond  # Todo. This is silly.
            if ( a = x.remains[ :uploading ] )
              if ( e = a.exception || a.error )
                return nil
              else
                count = count + a.active
              end
            end
          end
        end
        count
      end

      def print_remains_replication_printf h, k, m, n
        f = "%-14s %14d%7d  %18d\n"  # format
        s = sprintf f, h, k, m, n
        print s.sub( / +\Z/, "" )
      end

      def print_remains_replication
        print "HOSTNAME      RECEIVING(TOTAL ACTIVE)  REPLICATING(TOTAL)\n"
        k, m, n = nil, nil, nil
        work_on_every_component( false ) do |h, t, x|  # hostname, component type, proxy object
          if t == :cmond  # Todo. This is silly.
            if ( a = x.remains[ :receiving ] )
              if ( e = a.exception || a.error )
                print_remains_replication_printf h, e, '', ''
              else
                k = a.inactive + a.active
                m = a.active
              end
            end

            if ( a = x.remains[ :sending ] )
              if ( e = a.exception || a.error )
                print_remains_replication_printf h, e, '', ''
              else
                n = a.inactive + a.active
              end
            end

            if k && m && n
              print_remains_replication_printf h, k, m, n
              k, m, n = nil, nil, nil
            end
          end
          true
        end
        print "\n"
      end

      def remains_replication_active
        count = 0
        work_on_every_component( false ) do |h, t, x|  # hostname, component type, proxy object
          if t == :cmond  # Todo. This is silly.
            if ( a = x.remains[ :receiving ] )
              if ( e = a.exception || a.error )
                return nil
              else
                count = count + a.active
              end
            end
            if ( a = x.remains[ :sending ] )
              if ( e = a.exception || a.error )
                return nil
              else
                count = count + a.active
              end
            end
          end
        end
        count
      end

    end

  end
end
