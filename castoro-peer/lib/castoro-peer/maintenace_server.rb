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
      THRESHOLD = 3

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
            MaintenaceServerScheduler.instance.wait
            # print "#{"%.3f" % (t2 - @start_time)} #{"%8.3f" % (t2 - t1)} #{Thread.current}  #{"%8.3f" % (t3)}\n"
            # t2 = Time.new
            x = io.read_nonblock( 256 )
            # print "#{"%.3f" % (t2 - @start_time)} #{"%8.3f" % (t2 - t1)} #{Thread.current}  #{"%8.3f" % (t3)}  #{x.inspect}\n"
          rescue Errno::EAGAIN  # Errno::EAGAIN: Resource temporarily unavailable
            # print "#{"%.3f" % (t2 - @start_time)} #{"%8.3f" % (t2 - t1)} #{Thread.current}  #{"%8.3f" % (t3)}  EAGAIN\n"
            # p "retry"
            retry
          rescue EOFError => e  # EOFError "end of file reached"
            Log.notice e, "Health check: had been connected from #{peer_host}:#{peer_port}"
            return
          rescue IOError => e   # IOError: closed stream
            Log.warning e, "Health check: had been connected from #{peer_host}:#{peer_port}"
            return
          end

          x.length.times {
            io.write( "#{ServerStatus.instance.status_name} #{($AUTO_PILOT) ? "auto" : "off"} #{($DEBUG) ? "on" : "off"}\n" )
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

  end
end

