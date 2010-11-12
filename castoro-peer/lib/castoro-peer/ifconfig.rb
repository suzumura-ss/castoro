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
require "ipaddr"

module Castoro
  module Peer

    class IfConfig

      DEFAULT_OPTIONS = {
        :enum_if_proc => Proc.new {
                           ret = []
                           IO.popen '/sbin/ifconfig -a' do |pipe|
                             while line = pipe.gets do
                               ret << $1 if line =~ /inet\D+(\d+\.\d+\.\d+\.\d+)/
                             end
                           end
                           ret
                         },
      }

      ##
      # initialize.
      #
      def initialize options = {}
        @options                   = DEFAULT_OPTIONS.merge options
        @default_hostname          = Socket::gethostname
        @default_interface_address = IPSocket::getaddress @default_hostname
        @interface_addresses       = @options[:enum_if_proc].call
      end

      ##
      # default hostname
      #
      attr_reader :default_hostname

      ##
      # default interface address
      #
      attr_reader :default_interface_address

      ##
      # It is returned whether to possess the specified address. 
      #
      # === Args
      #
      # +interface_address+::
      #   interface address
      #
      def has_interface? interface_address
        @interface_addresses.include? interface_address
      end

      ##
      # ipaddress in the specified range of the address is returned.
      #
      # === Args
      #
      # +network_address+::
      #
      # === Exception
      #
      # * When satisfied Internet Protocol address doesn't exist.
      # * When two or more satisfied Internet Protocol addresses exist.
      # 
      # === Examples
      #
      #  # It is assumed that the following addresses are possessed.
      #  #   * 192.168.1.1
      #  #   * 192.168.2.22
      #  #   * 192.168.3.123
      #
      #  ifcfg = IfConfig.new
      #  p ifcfg.multicast_interface_by_network_address("192.168.2.0/24") #=> "192.168.2.22"
      #  p ifcfg.multicast_interface_by_network_address("192.168.1.0/24") #=> "192.168.1.1"
      #  p ifcfg.multicast_interface_by_network_address("192.168.2.0/23") #=> raise 'Too many candidates ..'
      #  p ifcfg.multicast_interface_by_network_address("192.168.4.0/24") #=> raise 'No candidate found ..'
      #
      def multicast_interface_by_network_address( network_address )
        n = IPAddr.new( network_address )
        a = @interface_addresses.select { |inet| n.include?( IPAddr.new( inet ) ) }

        if a.empty?
          s = 'No candidate found for the multicast network interface in the given network address'
          raise ArgumentError, "#{s}: #{network_address}"
        elsif a.size > 1
          s = 'Too many candidates for the multicast network interface in the given network address'
          raise ArgumentError, "#{s}: #{network_address}: candidates: " + a.join(' ')
        end

        a.first
      end

    end
  end
end
