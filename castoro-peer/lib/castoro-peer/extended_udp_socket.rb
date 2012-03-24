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
require 'castoro-peer/ticket'
require 'castoro-peer/log'

module Castoro
  module Peer

    class ExtendedUDPSocket < UDPSocket
      BUFFER_SIZE = 576  # Minimum reassembly buffer size

      def initialize
        super
        self.do_not_reverse_lookup = true
      end

      def bind host, port
        Log.debug "ExtendedUDPSocket.bind( #{host}, #{port} )" if $DEBUG
        super
      end

      def set_multicast_if if_addr
        interface = IPAddr.new( if_addr ).hton

        # select the default interface for outgoing multicasts
        Log.debug "IP_MULTICAST_IF   : #{if_addr}" if $DEBUG
        self.setsockopt Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, interface

        # disable loopback of outgoing multicasts
        Log.debug "IP_MULTICAST_LOOP : 0" if $DEBUG
        self.setsockopt Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, "\x00"
      end

      def join_multicast_group multicast_address, if_addr
        Log.debug "IP_ADD_MEMBERSHIP : #{multicast_address} #{if_addr}" if $DEBUG
        ip_mreq = IPAddr.new( multicast_address ).hton + IPAddr.new( if_addr ).hton
        self.setsockopt Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip_mreq
      end

      def sending data, host, port, ticket = nil
        ticket.mark unless ticket.nil?
        begin
          self.send( data, 0, host, port )
        rescue Errno::EINTR
          retry
        rescue => e
          s = debug_information data, host, port
          Log.notice( "UDP sendto: #{e.class} #{e.message} : from #{self.addr[3]}:#{self.addr[1]} to #{s}" )
        end
        ticket.mark unless ticket.nil?
        if $DEBUG
          s = debug_information data, host, port
          Log.debug "UDP O : #{s}"
        end
      end

      def receiving ticket = nil
        begin
          data, array = self.recvfrom( BUFFER_SIZE )
          ticket.mark unless ticket.nil?
        rescue Errno::EINTR
          retry
        rescue => e
          Log.notice( "UDP recvfrom: #{e.class} #{e.message} : receiving at #{self.addr[3]}:#{self.addr[1]}" )
          return nil
        end
        if $DEBUG
          family, port, hostname, ip = array
          s = debug_information data, ip, port
          Log.debug "UDP I : #{s}"
        end
        data
      end

      def debug_information data, host, port
        h = host.nil? ? 'nil' : host
        p = port.nil? ? 'nil' : port
        d = data.nil? ? 'nil' : data
        "#{h}:#{p} #{d}"
      end
    end

  end
end
