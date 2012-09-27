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

require File.dirname(__FILE__) + '/spec_helper.rb'

describe Castoro::Sender::UDP do
  before do
    @udp_port = 30150
  end

  context "when the logger, thread_count, subscriber argument is omitted." do
    it "should liberate socket resource" do
      h = Castoro::Protocol::UDPHeader.new "127.0.0.1", @udp_port
      d = Castoro::Protocol::Command::Nop.new
      10000.times {
        Castoro::Sender::UDP.start(nil) { |s| s.send h, d, "127.0.0.1", @udp_port }
      }
    end
  end

  context "when the logger, thread_count, subscriber argument is omitted." do
    before do
      @s = Castoro::Sender::UDP.new(nil)
    end

    it "should logger equals NilLogger" do
      l = @s.instance_variable_get :@logger
      l.should_not be_nil
      logdev = l.instance_variable_get :@logdev
      logdev.should be_nil
    end

    it "should alive? false" do
      @s.alive?.should be_false
    end

    it "should be able start>stop" do
      10000.times {
        @s.start
        @s.stop
      }
    end

    it "should be able start>send>stop" do
      h = Castoro::Protocol::UDPHeader.new "127.0.0.1", @udp_port
      d = Castoro::Protocol::Command::Nop.new
      10000.times {
        @s.start
        @s.send h, d, "127.0.0.1", @udp_port
        @s.stop
      }
    end

    after do
      @s.stop if @s.alive? rescue nil
    end
  end

end

