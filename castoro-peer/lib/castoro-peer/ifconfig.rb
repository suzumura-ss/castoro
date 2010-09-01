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

require 'singleton'
require 'socket'
require "ipaddr"

module Castoro
  module Peer

    class IfConfig
      include Singleton

      IFCONFIG_COMMAND = '/sbin/ifconfig -a'

      def initialize
        super
        @monitor = nil
        @mutex = Mutex.new
        load
      end

      def load
        @mutex.synchronize {
          @interface_addresses = get_all_interface_addresses
        }
      end

      alias_method :reload, :load

      def default_interface_address
        IPSocket::getaddress( Socket::gethostname )
      end

      def default_hostname
        # @hostname = Socket::gethostname unless defined? @hostname
        # @hostname
        Socket::gethostname
      end

      def has_interface?( interface_address )
        @mutex.synchronize {
          return @interface_addresses.include?( interface_address )
        }
      end

      def multicast_interface_by_network_address( network_address )
        n = IPAddr.new( network_address )
        @mutex.synchronize {
          a = @interface_addresses.select { |inet| n.include?( IPAddr.new( inet ) ) }
          if ( 1 < a.count )
            s = 'Too may candidates for the multicast network interface in the given network address'
            raise ArgumentError, "#{s}: #{network_address}: candidates: " + a.join(' ')
          elsif ( 0 == a.count )
            s = 'No candidate found for the multicast network interface in the given network address'
            raise ArgumentError, "#{s}: #{network_address}"
          end
          return a.shift
        }
      end

      protected

      def get_all_interface_addresses
        a = []
        IO.popen IFCONFIG_COMMAND do |pipe|
          while line = pipe.gets do
            a << $1 if line =~ /inet\D+(\d+\.\d+\.\d+\.\d+)/  # This works for both CentOS and Solaris
          end
        end
        a
      end

    end
  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      x = IfConfig.instance
      p x.default_interface_address
      p x.has_interface?( '127.0.0.1' )
      p x.has_interface?( '192.168.1.1' )
      p x.has_interface?( '192.168.223.20' )
      t = Thread.new {
        x.reload
        begin 
          p x.multicast_interface_by_network_address( '0.0.0.0/0' )
        rescue => e
          p e
        end
        begin 
          p x.multicast_interface_by_network_address( '192.168.223.0/24' )
          p x.multicast_interface_by_network_address( '192.168.223.0/255.255.255.0' )
        rescue => e
          p e
        end
        begin 
          p x.multicast_interface_by_network_address( '192.168.224.0/24' )
        rescue => e
          p e
        end
      }
      t.join
    end
  end
end
