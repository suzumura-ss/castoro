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

require 'castoro-groupctl/configurations'
require 'castoro-groupctl/tcp_socket'
require 'castoro-groupctl/channel'

module Castoro
  module Peer

    module Stub
      class Base
        def initialize hostname
          @hostname = hostname
        end

        def call command, args
          timelimit = 5  # in seconds
          client = TcpClient.new
          socket = client.timed_connect @hostname, port, timelimit
          channel = TcpClientChannel.new socket
          channel.send_command command, args
          x_command, response = channel.receive_response
          socket.close
          response
        end
      end

      class Cstartd < Base
        def port
          Configurations.instance.cstartd_comm_tcpport
        end
      end

      class Cagentd < Base
        def port
          Configurations.instance.cagentd_comm_tcpport
        end
      end
    end

  end
end
