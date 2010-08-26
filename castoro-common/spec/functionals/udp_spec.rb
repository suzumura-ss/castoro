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

require File.dirname(__FILE__) + '/../spec_helper.rb'

UDP_PORT     = 30100
UDP_PORT_CLI = 30101

describe Castoro::Sender::UDP, Castoro::Receiver::UDP do
  context "when specified subscriber." do
    before do
      @l = nil

      @s = Castoro::Sender::UDP.new(@l)
      @s.start

      n = Castoro::Protocol::Response::Nop.new(nil)
      @r = Castoro::Receiver::UDP.new(@l, UDP_PORT) { |h, d, i, p|
        @s.send h, n, h.ip, h.port
      }
      @r.start
    end

    it "should return valid NOP response" do

      received = 0

      r = Castoro::Receiver::UDP.new(@l, UDP_PORT_CLI) { |h, d, i, p|
        received += 1
      }
      r.start

      h = Castoro::Protocol::UDPHeader.new "127.0.0.1", UDP_PORT_CLI
      n = Castoro::Protocol::Command::Nop.new
      Castoro::Sender::UDP.start(@l) { |s|
        10.times { s.send h, n, "127.0.0.1", UDP_PORT }
      }

      until received >= 10; sleep 0.1; end

      r.stop
    end

    after do
      @r.stop if @r.alive? rescue nil
      @s.stop if @s.alive? rescue nil
    end
  end
end

