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

require 'thread'
require 'castoro-groupctl/components'

module Castoro
  module Peer
    
    class Test02

      def do_ps hosts
        c = PeerGroupComponent.new hosts
        n = c.total + 1
        XBarrier.instance.clients= n
        c.ps
        XBarrier.instance.wait nil
        XBarrier.instance.wait nil

        r = XBarrier.instance.results.select { |x| x }
        r.sort! do |a, b|
          if a.hostname == b.hostname
            a.target <=> b.target
          else
            a.hostname <=> b.hostname
          end
        end
        r.each do |x|
          x.message.each do |m|
            printf "%-12s%-12s%s\n", x.hostname, x.target, m
          end
        end
      end


      def do_status hosts
        c = CxxxdGroupComponent.new hosts
        n = c.total + 1
        # p n
        XBarrier.instance.clients= n
        c.status
        XBarrier.instance.wait nil
        XBarrier.instance.wait nil

        r = XBarrier.instance.results.select { |x| x }
        r.sort! do |a, b|
          if a.hostname == b.hostname
            a.target <=> b.target
          else
            a.hostname <=> b.hostname
          end
        end
        r.each do |x|
          y = x.message
          printf "%-12s%-12s%-8s%-8s%-8s\n", x.hostname, x.target, y['mode'], y['auto'], y['debug']
        end
      end


      def xxx
        hosts = %w[ stdx200 stdx201 stdx202 ]
        x = PeerGroupComponent.new hosts

        n = x.total + 1
        XBarrier.instance.clients= n

        #x.stop
        x.start

        XBarrier.instance.wait nil

        XBarrier.instance.wait nil

        XBarrier.instance.results.each do |x|
          p x
        end
      end

      def yyy
        hosts = %w[ stdx200 stdx201 stdx202 ]
        x = PeerGroupComponent.new hosts

        n = x.total + 1
        XBarrier.instance.clients= n
        x.start
        XBarrier.instance.wait nil  # let slaves start their tasks
        t = XBarrier.instance.timedwait nil, 5  # wait until all slaves finish their tasks
        if t == :etimedout
          #
        end
        XBarrier.instance.results.each do |x|
          p x
        end

        # confirm if an interruption request has been received
        
        x.do_ps
        XBarrier.instance.wait nil  # let slaves start their tasks
        t = XBarrier.instance.timedwait nil  # wait until all slaves finish their tasks
        if t == :etimedout
          #
        end
        XBarrier.instance.results.each do |x|
          p x
        end

      end

    end

    # hosts = %w[ stdx200 stdx201 stdx202 ]
    hosts = %w[ stdx200 ]
    x = Test02.new
    x.do_status hosts
#    x.do_ps 

    #    x.xxx

  end
end
