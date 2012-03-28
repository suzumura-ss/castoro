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

require 'time'
require 'socket'
require 'syslog'
require 'singleton'
require 'thread'
require 'castoro-peer/pipeline'

# require 'logger'  # Todo: a way to switch an underlaying logging system from syslog to logger

module Castoro
  module Peer

    class Log
      FACILITY = Syslog::LOG_DAEMON

      @@output = $stdout
      @@queue = Pipeline.new
      @@thread = nil

      def Log.output=( output )
        @@output = output
      end

      def Log.output
        @@output
      end

      def Log.log( severity, label, m, *args )
        t = Time.new
        a = *args
        z = (0 < a.size) ? " #{a.join(' ')}" : ""
        @@queue.enq( [ severity, label, m, z, t ] )
      end

      def Log.start
        @@thread = Thread.new {
          loop do
            begin
              break unless Log.worker()
            rescue => e
              ExtendedSyslog.instance.log( Syslog::LOG_WARNING, "Exception: %s \"%s\"", e.class, e.message )
            end
          end
          @@thread = nil
        }
      end

      def Log.start_again
        Log.start
      end

      def Log.running?
        @@thread && @@thread.alive?
      end

      def Log.stop
        @@queue.enq nil if running?
        begin
          sleep 0.01
        end while running?
      end

      def Log.worker
        severity, label, m, z, t = @@queue.deq
        return nil if severity.nil?

        if ( m.is_a? Exception )

          c, x, bt = m.class, m.message, m.backtrace.slice(0,5).inspect
          m.message.gsub!(/\r/,"\\r")
          m.message.gsub!(/\n/,"\\n")
          @@syslog.log( severity, "Exception: %s \"%s\" %s%s", c, x, bt, z )

          if ( @@output )
            host = Socket::gethostname
            printf( "%s.%06d %s %s Exception: %s \"%s\" %s%s\n", t.iso8601, t.usec, host, label, c, x, bt, z )
            @@output.flush
          end
        else
          y = m.gsub(/\r/,"\\r")
          y.gsub!(/\n/,"\\n")
          # y.gsub!(/\\\//, '/')

          # c = ( $DEBUG ) ? " ; [#{caller[1]}]" : ''
          # c = ( $DEBUG ) ? " ; [#{caller.slice(1,3).join(', ')}]" : ''
          # c =              " ; [#{caller.slice(1,3).join(', ')}]" 
          # @@syslog.log( severity, "%s%s%s", y, c, z )

          @@syslog.log( severity, "%s%s", y, z )

          if ( @@output )
            host = Socket::gethostname
            printf( "%s.%06d %s %s %s%s%s\n", t.iso8601, t.usec, host, label, y, c, z )
            @@output.flush
          end
        end
        return true
      end

      def Log.emerg  ( m, *args ) ; log( Syslog::LOG_EMERG,     'EMERG', m, *args ) ; end
      def Log.alert  ( m, *args ) ; log( Syslog::LOG_ALERT,     'ALERT', m, *args ) ; end
      def Log.crit   ( m, *args ) ; log( Syslog::LOG_CRIT,       'CRIT', m, *args ) ; end
      def Log.err    ( m, *args ) ; log( Syslog::LOG_ERR,         'ERR', m, *args ) ; end
      def Log.warning( m, *args ) ; log( Syslog::LOG_WARNING, 'WARNING', m, *args ) ; end
      def Log.notice ( m, *args ) ; log( Syslog::LOG_NOTICE,   'NOTICE', m, *args ) ; end
      def Log.info   ( m, *args ) ; log( Syslog::LOG_INFO,       'INFO', m, *args ) ; end
      def Log.debug  ( m, *args ) ; log( Syslog::LOG_DEBUG,     'DEBUG', m, *args ) if $DEBUG ; end

      private

      class ExtendedSyslog
        include Singleton
        
        def initialize
          identity = $0.sub(/.*\//, '')
          option = Syslog::LOG_PID | Syslog::LOG_NDELAY | Syslog::LOG_NOWAIT
          Syslog.open( identity, option, FACILITY )
        end

        def log( *args )
          Syslog.log( *args )
        end
      end

      @@syslog = ExtendedSyslog.instance

      # Todo: ...
      Log.start
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      # Log.output = nil

      Log.notice( 'test notice' )
      Log.debug( 'test debug' ) if $DEBUG

      class A
        def f
          raise StandardError, "mmm"
        rescue => e
          Log.warning e, "hhh"
        end
      end

      x = A.new
      x.f
    end
  end
end
