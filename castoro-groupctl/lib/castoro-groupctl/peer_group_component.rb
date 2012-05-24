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

      def number_of_components
        n = 0  # number
        @entries.values.each { |c| n = n + c.size }  # components
        n
      end

      def do_ps
        @entries.values.each do |c|  # components
          c.values.each { |x| x.do_ps }  # proxy object
        end
      end

      def obtain_ps_header
        @entries.values.each do |c|  # components
          c.values.each do |x|  # proxy object
            return x.ps.header if x.ps.header and x.ps.header != ''
          end
        end
        nil
      end

      def print_ps
        f = "%-14s%-14s%s\n"  # format
        printf f, 'HOSTNAME', 'DAEMON', obtain_ps_header
        @entries.each do |h, c|  # hostname, components
          c.each do |t, x|  # component type, proxy object
            # p x
            if x.ps.error
              printf f, h, t, x.ps.error
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
                printf f, h, t, '(error occured)'
              end
            end
          end
          puts ''
        end
      end

      def alive?
        r = nil
        @peers.each do |x|
          a = x.alive?
          a.nil? and return nil
          if r.nil?
            r = a
          elsif r != a
            return nil
          end
        end
        r
      end

      def do_status
        @peers.each { |x| x.do_status }
      end

      def print_status
        @peers.each { |x| x.print_status }
      end

      def do_start
        @peers.each { |x| x.do_start }
      end

      def print_start
        @peers.each { |x| x.print_start }
      end

      def do_stop
        @peers.each { |x| x.do_stop }
      end

      def print_stop
        @peers.each { |x| x.print_stop }
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
