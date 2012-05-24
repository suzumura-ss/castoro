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

require 'castoro-groupctl/peer_component'

module Castoro
  module Peer

    class PeerGroupComponent
      def initialize entries
        @peers = entries.map do |h, t|  # hostname, targets
          PeerComponent.new h, t
        end
      end

      def number_of_targets
        c = 0  # count
        @peers.each { |x| c = c + x.number_of_targets }
        c
      end

      def do_ps
        @peers.each { |x| x.do_ps }
      end

      def print_ps
        @peers[0].print_ps_header
#        puts ''
        @peers.each { |x| x.print_ps_body }
      end

      def ps_alive?
        r = nil
        @peers.each do |x|
          a = x.ps_alive?
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
