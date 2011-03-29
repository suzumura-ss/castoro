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
require 'fcntl'

require 'castoro-peer/pre_threaded_tcp_server'
require 'castoro-peer/log'
require 'castoro-peer/scheduler'

module Castoro
  module Peer

    class TCPHealthCheckPatientServer < PreThreadedTcpServer
      THRESHOLD = 5.5

      def initialize( port, concurrence = 5 )
        super( port, '0.0.0.0', concurrence )
      end

      def serve( io )
        peer_port, peer_host = Socket.unpack_sockaddr_in( io.getpeername )
        Log.notice "Health check: connection established from #{peer_host}:#{peer_port}"

#        flags = io.fcntl(Fcntl::F_GETFL, 0)
#        flags = flags | Fcntl::O_NONBLOCK
#        io.fcntl(Fcntl::F_SETFL, flags)
#        flags = io.fcntl(Fcntl::F_GETFL, 0)

        # t2 = Time.new
        last_time = nil

        loop do 
          Thread.current.priority = 3
          x = nil
          begin
            # t1 = Time.new
            # t3 = t1 - t2
            MaintenaceServerSingletonScheduler.instance.wait
            # print "#{"%.3f" % (t2 - @start_time)} #{"%8.3f" % (t2 - t1)} #{Thread.current}  #{"%8.3f" % (t3)}\n"
            # t2 = Time.new
            x = io.read_nonblock( 256 )
            # print "#{"%.3f" % (t2 - @start_time)} #{"%8.3f" % (t2 - t1)} #{Thread.current}  #{"%8.3f" % (t3)}  #{x.inspect}\n"
          rescue Errno::EAGAIN  # Errno::EAGAIN: Resource temporarily unavailable
            # print "#{"%.3f" % (t2 - @start_time)} #{"%8.3f" % (t2 - t1)} #{Thread.current}  #{"%8.3f" % (t3)}  EAGAIN\n"
            # p "retry"
            retry
          rescue EOFError => e  # EOFError "end of file reached"
            if ( @stop_requested )
              @finished = true
              return
            else
              Log.notice e, "Health check: had been connected from #{peer_host}:#{peer_port}"
              return
            end
          rescue IOError => e   # IOError: closed stream
            Log.warning e, "Health check: had been connected from #{peer_host}:#{peer_port}"
            return
          end

          x.length.times {
            # Use syswrite() here and don't use write() or puts().
            # write() in Ruby 1.9.1 does a lot of things causing waste of time, 
            # especially releasing the global_vm_lock and obtaining it
            io.syswrite( "#{ServerStatus.instance.status_name} #{($AUTO_PILOT) ? "auto" : "off"} #{($DEBUG) ? "on" : "off"}\n" )
          }

          current = Time.new
          if ( last_time )
            elapsed = current - last_time
            Log.notice "Health check: the last command came from #{peer_host}:#{peer_port} #{"%.3fs" % (elapsed)} ago" if THRESHOLD < elapsed 
          end
          last_time = current
        end
      rescue => e
        Log.warning e
      end
    end


    class TcpMaintenaceServer < PreThreadedTcpServer
      def initialize( port )
        super( port, '0.0.0.0', 10 )
        @hostname = Configurations.instance.HostnameForClient
        @program = $0.sub(/.*\//, '')
      end

      def serve( io )
        begin
          serve_impl( io )
        rescue => e
          Log.err e
          sleep 0.5
        end
      end

      def serve_impl( io )
        @io = io
        while ( line = @io.gets )
          line.chomp!
          next if line =~ /\A\s*\Z/
          begin
            @a = line.split(' ')
            command = @a.shift.downcase
            case command
            when 'quit'    ; break
            when 'version' ; do_version
            when 'help'    ; do_help
            when 'shutdown'
              @io.syswrite( "#{@hostname} #{@program} is going to shutdown ...\n" )
              Log.notice( "Shutdown is requested." )
              do_shutdown
            when 'health'
              @io.syswrite( "#{ServerStatus.instance.status_name} #{($AUTO_PILOT) ? "auto" : "off"} #{($DEBUG) ? "on" : "off"}\n" )
            when 'mode'   ; do_mode
            when '_mode'  ; do_backdoor_mode
            when 'auto'   ; do_auto
            when 'reload' ; do_reload
            when 'debug'  ; do_debug
            when 'dump'   ; do_dump
            when 'status' ; do_status
            when 'stat'   ; do_stat
            when 'inspect' ; do_inspect
            when 'gc_profiler' ; do_gc_profiler
            when 'gc'     ; do_gc
            else
              raise StandardError, "400 Unknown command: #{command} ; try help command"
            end
          rescue StandardError => e
            @io.syswrite( "#{e.message}\n" )
          rescue => e
            @io.syswrite( "500 Internal Server Error: #{e.class} #{e.message}\n" )
          end
        end
      end

      def do_version
        t = Time.new
        @io.syswrite( "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} Version: #{PROGRAM_VERSION}\n" )
      end

      def do_mode
        x = @a.shift
        if (x)
          x.downcase!
          ServerStatus.instance.status_name = x
        end
        x = ServerStatus.instance.status_name
        @io.syswrite( "run mode: #{x}\n" )
      end

      def do_backdoor_mode
        x = @a.shift
        if ( $AUTO_PILOT )
          if (x)
            x.downcase!
            ServerStatus.instance.status_name = x
          end
          x = ServerStatus.instance.status_name
          io.syswrite( "run mode: #{x}\n" )
        else
          if (x)
            io.syswrite( "run mode cannot be automatically altered when auto is disable.\n" )
          else
            x = ServerStatus.instance.status_name
            io.syswrite( "run mode: #{x}\n" )
          end
        end
      end

      def do_auto
        x = @a.shift
        if (x)
          x.downcase!
          case (x) 
          when 'auto' ; $AUTO_PILOT = true
          when 'off'  ; $AUTO_PILOT = false
          when nil  ; 
            # Todo: does error message need  400?
          else raise StandardError, "400 Unknown parameter: #{x} ; auto [off|auto]"
          end
        end
        @io.syswrite( "auto: " + ( ($AUTO_PILOT) ? "auto" : "off")  + "\n" )
      end

      def do_debug
        x = @a.shift
        if (x)
          x.downcase!
          case (x) 
          when 'on' ; $DEBUG = true
          when 'off'; $DEBUG = false
          when nil  ; 
          else raise StandardError, "400 Unknown parameter: #{x} ; debug [on|off]"
          end
        end
        @io.syswrite( "debug mode: " + ( ($DEBUG) ? "on" : "off")  + "\n" )
      end

      def do_reload
        @io.syswrite( "400 reload is not implemented in #{@program}.\n" )
      end

      def do_dump
        @io.syswrite( "400 dump is not implemented in #{@program}.\n" )
      end

      def do_status
        @io.syswrite( "400 status is not implemented in #{@program}.\n" )
      end

      def do_stat
        @io.syswrite( "400 stat is not implemented in #{@program}.\n" )
      end

      def do_inspect
        t = Time.new
        @io.syswrite "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} ObjectSpace.each_object:\n"
        count = 0
        ObjectSpace.each_object { |x|
          begin
            @io.syswrite "#{"0x%08x" % x.object_id}\t#{x.class}\t#{x.inspect}\n"
          rescue NotImplementedError => e
            @io.syswrite "#{e}\n"
          end
          count = count + 1
        }
        @io.syswrite "The number of objects including NotImplementedError: #{count}\n"
      end

      def do_gc_profiler
        t = Time.new
        x = @a.shift
        if (x)
          x.downcase!
          case (x) 
          when 'off'    ; GC::Profiler.disable
          when 'on'     ; GC::Profiler.enable
          when 'report'
            if ( GC::Profiler.enabled? )
              @io.syswrite( "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} GC::Profiler.report:\n" )
              GC::Profiler.report( @io )
              @io.syswrite( "\n" )
            else
              @io.syswrite( "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} GC::Profiler is disabled. Try gc_profiler on\n" )
            end
          when nil  ; 
          else raise StandardError, "400 Unknown parameter: #{x} ; gc_profiler [off|on|report]"
          end
        end
        unless ( x == 'report' )
          @io.syswrite( "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} gc_profiler: " + ( (GC::Profiler.enabled?) ? "on" : "off")  + "\n" )
        end
      end

      def do_gc
        t = Time.new
        x = @a.shift
        if (x)
          x.downcase!
          case (x) 
          when 'start'
            t1 = Time.new
            GC.start
            t2 = Time.new
            @io.syswrite( "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} GC finished: #{"%.1fms" % ((t2 - t1) * 1000)}\n" ) 
          when 'count'
            @io.syswrite( "#{t.iso8601}.#{"%06d" % t.usec} #{@hostname} #{@program} GC.count: #{GC.count}\n" )
          else
            raise StandardError, "400 Unknown parameter: #{x} ; gc [start|count]"
          end
        else
          @io.syswrite( "Usage: gc [start|count]\n" )
        end
      end
    end

  end
end

