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

    class PeerGroupComponent
      def initialize hostnames
        @peers = hostnames.map do |h|  # hostname
          PeerComponent.new h
        end
      end

      def number_of_targets
        c = 0  # count
        @peers.each do |x|
          c = c + x.number_of_targets
        end
        c
      end

      def do_ps
        @peers.each do |x|
          x.do_ps
        end
      end

      def print_ps
        @peers.each do |x|
          x.print_ps
        end
      end

      def ps_running?
        r = nil
        @peers.each do |x|
          x = x.ps_running?
          x.nil? and return nil
          if r.nil?
            r = x
          elsif r != x
            return nil
          end
        end
        r
      end

      def do_status
        @peers.each do |x|
          x.do_status
        end
      end

      def print_status
        @peers.each do |x|
          x.print_status
        end
      end

      def do_start
        @peers.each do |x|
          x.do_start
        end
      end

      def print_start
        @peers.each do |x|
          x.print_start
        end
      end

      def do_stop
        @peers.each do |x|
          x.do_stop
        end
      end

      def print_stop
        @peers.each do |x|
          x.print_stop
        end
      end

      def do_mode mode
        @peers.each do |x|
          x.do_mode mode
        end
      end

      def print_mode
        @peers.each do |x|
          x.print_mode
        end
      end

      def ascend_mode mode
        @peers.each do |x|
          x.ascend_mode mode
        end
      end

      def descend_mode mode
        @peers.each do |x|
          x.descend_mode mode
        end
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
        @peers.each do |x|
          x.do_auto auto
        end
      end

      def print_auto
        @peers.each do |x|
          x.print_auto
        end
      end
    end

  end
end
