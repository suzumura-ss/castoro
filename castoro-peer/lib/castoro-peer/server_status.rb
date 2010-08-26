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
require 'castoro-peer/log'

module Castoro
  module Peer

    ########################################################################
    # Server Status
    ########################################################################

    # Todo: more appropreate API

    class ServerStatus
      include Singleton

      ACTIVE      = 30
      DEL_REP     = 27
      FIN_REP     = 25
      REP         = 23
      READONLY    = 20
      DEAD        = 12
      DRAIN       = 11
      MAINTENANCE = 10
      UNKNOWN     =  0

      def initialize
        @mutex = Mutex.new
        @status = MAINTENANCE
      end

      # Todo: has to stop or start the workers to match the status
      def status=( s )
        last_status = nil
        new_status = nil
        @mutex.synchronize {
          last_status = @status
          @status = s
          new_status = s
        }
        Log.notice( "STATUS changed from #{ServerStatus.status_to_s(last_status)} to #{ServerStatus.status_to_s(new_status)}" )
      end

      def status
        @status
      end

      def status_name= ( x )
        self.status = ServerStatus.status_name_to_i ( x )
      end

      def self.status_name_to_i ( x )
        case (x)
          # Todo: use constant values
        when 'online'   , '30' ; ACTIVE
        when 'del_rep'  , '27' ; DEL_REP
        when 'fin_rep'  , '25' ; FIN_REP
        when 'rep'      , '23' ; REP
        when 'readonly' , '20' ; READONLY
        when 'offline'  , '10' ; MAINTENANCE
        when 'unknown'  , '0'  ; UNKNOWN
        else raise StandardError, "Unknown parameter: #{x} ; mode [offline|readonly|rep|fin_rep|del_rep|online]"
        end
      end

      def status_name
        s = nil
        @mutex.synchronize {
          s = @status
        }
        ServerStatus.status_to_s( s ) 
      end

      def ServerStatus.status_to_s( s )
          x = case ( s ) 
              when ACTIVE      , '30' ; '30 online'
              when DEL_REP     , '27' ; '27 del_rep'
              when FIN_REP     , '25' ; '25 fin_rep'
              when REP         , '23' ; '23 rep'
              when READONLY    , '20' ; '20 readonly'
              when MAINTENANCE , '10' ; '10 offline'
              when UNKNOWN     , '0'  ; '0 unknown'
              # else raise StandardError, "Unknown status: #{s}"
              else ; '? ?'
              end
          x
      end
    end

  end
end
