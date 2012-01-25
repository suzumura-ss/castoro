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

CONSOLE   = 30150
UNICAST   = 30151
MULTICAST = 30159
WATCHDOG  = 30153

SETTINGS = {
  "multicast_addr" => "239.192.1.1",
#  "multicast_device_addr" => IPSocket::getaddress(Socket::gethostname),
  "multicast_device_addr" => "127.0.0.1",
  "gateway" => {
    "console_port" => CONSOLE,
    "unicast_port" => UNICAST,
    "multicast_port" => MULTICAST,
    "watchdog_port" => WATCHDOG,
    "watchdog_logging" => false,
  },
  "master" => true,
}

describe Castoro::Gateway::Facade do
  before do
    # mock for Logger
    @logger = mock(Logger)
    @logger.stub!(:info)
    @logger.stub!(:debug)

    @facade = Castoro::Gateway::Facade.new(@logger, SETTINGS)
  end

  context "when initialized" do
    it "should be able start > stop > start ..." do
      100.times {
        @facade.start
        @facade.stop
      }
    end

    it "should be created an instance of Castoro::Gateway::Facade" do
      @facade.should be_kind_of Castoro::Gateway::Facade
    end

    it "should have methods of Castoro::Gateway::Facade" do
      @facade.should respond_to :start, :stop, :alive?, :recv
    end

    it "should be set variables correctly" do
      @facade.instance_variable_get(:@logger).nil?.should be_false
      @facade.instance_variable_get(:@locker).should be_kind_of Monitor
      @facade.instance_variable_get(:@recv_locker).should be_kind_of Monitor

      @facade.instance_variable_get(:@gup).should == UNICAST
      @facade.instance_variable_get(:@gmp).should == MULTICAST
      @facade.instance_variable_get(:@gwp).should == WATCHDOG
      @facade.instance_variable_get(:@watchdog_logging).should be_false
    end

    context "when start" do
      before do
        # mock for UDPSocket
        @udpsock = mock(UDPSocket)
        UDPSocket.stub!(:new).and_return(@udpsock)
        @udpsock.stub!(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gup))
        @udpsock.stub!(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gmp))
        @udpsock.stub!(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gwp))
        @udpsock.stub!(:setsockopt).with(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, @facade.instance_variable_get(:@mreqs)[0])
        @udpsock.stub!(:setsockopt).with(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, @facade.instance_variable_get(:@mreqs)[0])
        @udpsock.stub!(:setsockopt).with(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)
        @udpsock.stub!(:recvfrom)
        @udpsock.stub!(:closed?)
        @udpsock.stub!(:close)
      end

      it "#alive? should be true." do
        @facade.start
        @facade.alive?.should be_true
      end

      it "should raise error if facade is alive." do
        @facade.start
        Proc.new{
          @facade.start
        }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
      end

      it "UDPSocket#new should be called 3 times" do
        UDPSocket.should_receive(:new).exactly(3)
        @facade.start
      end

      it "UDPSocket#bind should be called 3 times" do
        @udpsock.should_receive(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gup)).exactly(1)
        @udpsock.should_receive(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gmp)).exactly(1)
        @udpsock.should_receive(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gwp)).exactly(1)

        @facade.start
      end

      it "UDPSocket#setsockopt should be called 4 times" do
        @udpsock.should_receive(:setsockopt).
          with(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, @facade.instance_variable_get(:@mreqs)[0]).
          exactly(2)

        @udpsock.should_receive(:setsockopt).
          with(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0).
          exactly(2)

        @facade.start
      end

      after do
        @facade.stop
      end

    end

    context "when stop" do
      before do
        # mock for UDPSocket
        @udpsock = mock(UDPSocket)
        UDPSocket.stub!(:new).and_return(@udpsock)
        @udpsock.stub!(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gup))
        @udpsock.stub!(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gmp))
        @udpsock.stub!(:bind).with("0.0.0.0", @facade.instance_variable_get(:@gwp))
        @udpsock.stub!(:setsockopt).with(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, @facade.instance_variable_get(:@mreqs)[0])
        @udpsock.stub!(:setsockopt).with(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, @facade.instance_variable_get(:@mreqs)[0])
        @udpsock.stub!(:setsockopt).with(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, 0)
        @udpsock.stub!(:recvfrom)
        @udpsock.stub!(:closed?)
        @udpsock.stub!(:close)

        @facade.start
      end

      it "#alive? should be false." do
        @facade.stop
        @facade.alive?.should be_false
      end

      it "should raise error if facade is not alive." do
        @facade.stop
        Proc.new{
          @facade.stop
        }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
      end

      it "UDPSocket#setsockopt should be called 2 times" do
        @udpsock.should_receive(:setsockopt).
          with(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, @facade.instance_variable_get(:@mreqs)[0]).
          exactly(2)

        @facade.stop
      end

      it "UDPSocket#close should be called 3 times" do
        @udpsock.should_receive(:close).exactly(3)
        @facade.stop
      end

      it "Logger#info should be called once" do
        @logger.should_receive(:info).exactly(1)
        @facade.stop
      end

      it "variables should be set nil." do
        @facade.stop

        @facade.instance_variable_get(:@unicast).should be_nil
        @facade.instance_variable_get(:@multicast).should be_nil
        @facade.instance_variable_get(:@watchdog).should be_nil
      end
    end

    context "when recv" do
      before do
        @udp_sender  = Castoro::Sender::UDP.new @logger
        @udp_header  = Castoro::Protocol::UDPHeader.new "999.3.2.1", 99999
        @nop    = Castoro::Protocol::Command::Nop.new
        @alive  = Castoro::Protocol::Command::Alive.new "host", 30, 1000
        @status = Castoro::Protocol::Command::Status.new
      end

      it "should return nil if facade is not alive" do
        @facade.recv.should be_nil
      end

      it "should return nil if facade receive nothing " do
        @facade.start
        @facade.recv.should be_nil
      end

      it "should be able to receive at unicast port" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop, "127.0.0.1", UNICAST

        @logger.should_receive(:debug).exactly(1)
        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s
      end

      it "should be able to receive at multicast port" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop, "127.0.0.1", MULTICAST

        @logger.should_receive(:debug).exactly(1)
        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s
      end

      it "should be able to receive at watchdog port without Logger#debug" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop, "127.0.0.1", WATCHDOG

        @logger.should_receive(:debug).exactly(0)
        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s

        @facade.recv.should be_nil
      end

      it "should be able to receive at watchdog port with Logger#debug" do
        @facade.instance_variable_set(:@watchdog_logging, true)
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop, "127.0.0.1", WATCHDOG

        @logger.should_receive(:debug).exactly(1)
        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s

        @facade.recv.should be_nil
      end

      it "should be able to receive 2 data" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop,   "127.0.0.1", MULTICAST
        @udp_sender.send @udp_header, @alive, "127.0.0.1", WATCHDOG

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Alive
        ret[1].to_s.should == @alive.to_s

        @facade.recv.should be_nil
      end

      it "should be able to receive 2 data" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop,   "127.0.0.1", UNICAST
        @udp_sender.send @udp_header, @alive, "127.0.0.1", WATCHDOG

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Alive
        ret[1].to_s.should == @alive.to_s

        @facade.recv.should be_nil
      end

      it "should be able to receive 2 data" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop,   "127.0.0.1", UNICAST
        @udp_sender.send @udp_header, @alive, "127.0.0.1", MULTICAST

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Alive
        ret[1].to_s.should == @alive.to_s

        @facade.recv.should be_nil
      end

      it "should be able to receive 3 data" do
        @facade.start
        @udp_sender.start
        @udp_sender.send @udp_header, @nop,   "127.0.0.1", UNICAST
        @udp_sender.send @udp_header, @alive,   "127.0.0.1", MULTICAST
        @udp_sender.send @udp_header, @status, "127.0.0.1", WATCHDOG

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Nop
        ret[1].to_s.should == @nop.to_s

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Alive
        ret[1].to_s.should == @alive.to_s

        ret = @facade.recv

        ret[0].should be_kind_of Castoro::Protocol::UDPHeader
        ret[0].to_s.should == @udp_header.to_s

        ret[1].should be_kind_of Castoro::Protocol::Command::Status
        ret[1].to_s.should == @status.to_s

        @facade.recv.should be_nil
      end

      after do

      end
    end
    
    after do
      @facade.stop if @facade.alive? rescue nil
      @facade = nil
    end

  end
end

