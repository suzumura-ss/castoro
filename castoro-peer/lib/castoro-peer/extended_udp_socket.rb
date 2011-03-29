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
require 'castoro-peer/configurations'
require 'castoro-peer/ticket'
require 'castoro-peer/log'

module Castoro
  module Peer

    class PartlyExtendedUDPSocket < UDPSocket
      BUFFER_SIZE = 576  # Minimum reassembly buffer size

      def sending( data, host, port, ticket = nil )
        s = debug_information( data, host, port )
        unless ( data.nil? || host.nil? || port.nil? )
          ticket.mark unless ticket.nil?
          begin
            self.send( data, 0, host, port )
          rescue Errno::EINTR
            retry
          rescue => e
            Log.notice( "UDP sendto: #{e.class} #{e.message} : from #{self.addr[3]}:#{self.addr[1]} to #{s}" )
          end
          ticket.mark unless ticket.nil?
          # Log.debug( "UDP O : #{s}" ) if $DEBUG
          # p port
          Log.debug( "UDP O : #{s}" ) if $DEBUG and port != 30113 and port != 40113
        else
          Log.notice( "UDP sendto: invalid parameters : #{s}" )
        end
      end

      def receiving( ticket = nil )
        begin
          data, array = self.recvfrom( BUFFER_SIZE )
          ticket.mark unless ticket.nil?
        rescue Errno::EINTR
          retry
        rescue => e
          Log.notice( "UDP recvfrom: #{e.class} #{e.message} : receiving at #{self.addr[3]}:#{self.addr[1]}" )
          return nil
        end
        if ( $DEBUG )
          # family, port, hostname, ip = array
          port, ip = array[1], array[3]
          s = debug_information( data, ip, port )
          Log.debug( "UDP I : #{s}" ) if $DEBUG and self.addr[1] != 30113 and self.addr[1] != 40113
        end
        data
      end

      protected

      def debug_information( data, host, port )
        h = host.nil? ? 'nil' : host
        p = port.nil? ? 'nil' : port
        d = data.nil? ? 'nil' : data
        sprintf( "%s:%s %s", h, p, d )
      end
    end


    class ExtendedUDPSocket < PartlyExtendedUDPSocket
      def initialize
        super
        self.do_not_reverse_lookup = true
        if_addr = Configurations.instance[ :MulticastIf ]
        interface = IPAddr.new( if_addr ).hton
        Log.debug( "ExtendedUDPSocket.new : Multicast IP_MULTICAST_IF  : #{if_addr}" )
#        p caller
        self.setsockopt( Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, interface )
        self.setsockopt( Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, "\x00" )
      end

      def bind( host, port )
        if ( isClassD?( host ) )
          multicast_address = host
          if_addr = Configurations.instance[ :MulticastIf ]
          ip_mreq = IPAddr.new( multicast_address ).hton + IPAddr.new( if_addr ).hton
          Log.debug( "ExtendedUDPSocket.bind: Multicast IP_ADD_MEMBERSHIP: #{multicast_address} #{if_addr}" )
          self.setsockopt( Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip_mreq )
          Log.debug( "bind( 0.0.0.0, #{port} )" )
          super( '0.0.0.0', port )
        else
          Log.debug( "bind( #{host}, #{port} )" )
          super
        end
      end

      protected

      def isClassD?( ip )
        ip =~ /\A(\d+)/ and x = $1.to_i and 224 <= x && x <= 239
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      Configurations.instance.load( 'csd.conf' )
      s = ExtendedUDPSocket.new
      s.bind( "239.192.1.1", 10000 )
      p = Castoro::UdpPacket.new( nil, nil, nil )
      s.sending( p )
      p = Castoro::UdpPacket.new( "Hello", nil, nil )
      s.sending( p )
      p = Castoro::UdpPacket.new( "Hello", "127.0.0.1", "10000" )
      s.sending( p )
      p = Castoro::UdpPacket.new( "MMMMM", "239.192.1.1", "10000" )
      s.sending( p )
      p = Castoro::UdpPacket.new( "Hello", "127.0.0.1", "-1" )
      s.sending( p )
      p = s.receiving
      p p
      p = s.receiving
      p p
    end
  end
end
