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

describe Castoro::Gateway::MasterWorkers do
  before(:all) do
    @logger = Logger.new(ENV['DEBUG'] ? STDOUT : nil)
    @broadcast_addr = ENV['BROADCAST'] || '192.168.1.255'
    @device_addr    = ENV['DEVICE']    || IPSocket.getaddress(Socket.gethostname)
    @port           = ENV['PORT']      || 30109
    @mock_port      = ENV['MOCK_PORT'] || 30110
    @broadcast_port = ENV['BROADCAST_PORT'] || 30108
    @facade = Object.new
  end

  describe "given valid constructor argument" do
    before do
      @w = Castoro::Gateway::MasterWorkers.new @logger, 1,
        @facade, @broadcast_addr, @device_addr, @port, @broadcast_port
    end

    it "should be able to start" do
      @facade.stub!(:recv)
      @w.start
      sleep 0.5
    end

    context "given nop request" do
      before do
        header = Castoro::Protocol::UDPHeader.new '127.0.0.1', @mock_port, 0
        nop    = Castoro::Protocol::Command::Nop.new
        requests = [
          [ header, nop ],
        ]
        @facade.stub!(:recv).with(no_args).and_return { requests.pop }
      end

      it "should return nop response" do
        received = false
        receiver = Castoro::Receiver::UDP.new(@logger, @mock_port) { |h, d, p, i|
          received = true if d.kind_of?(Castoro::Protocol::Response::Nop)         
        }
        receiver.start

        @w.start
        sleep 0.5

        receiver.stop
        received.should == true
      end
    end

    context "given get request with nothing island" do
      before do
        header = Castoro::Protocol::UDPHeader.new '127.0.0.1', @mock_port, 0
        get    = Castoro::Protocol::Command::Get.new '1.2.3', nil
        requests = [
          [ header, get ],
        ]
        @facade.stub!(:recv).with(no_args).and_return { requests.pop }
      end

      it "should send broadcast" do
        received = false
        receiver = Castoro::Receiver::UDP.new(@logger, @broadcast_port) { |h, d, p, i|
          received = true if d.kind_of?(Castoro::Protocol::Command::Get)
        }
        receiver.start

        @w.start
        sleep 0.5

        receiver.stop
        received.should == true
      end
    end

    context "given get request with island" do
      before do
        header = Castoro::Protocol::UDPHeader.new '127.0.0.1', @mock_port, 0
        get    = Castoro::Protocol::Command::Get.new '1.2.3', 'efc00101'
        requests = [
          [ header, get ],
        ]
        @facade.stub!(:recv).with(no_args).and_return { requests.pop }
      end

      it "should send multicast" do
        received = false
        receiver = Castoro::Receiver::UDP::Multicast.new(@logger, @port, 'efc00101'.to_island.to_ip, @device_addr) { |h,d,p,i|
          received = true if d.kind_of?(Castoro::Protocol::Command::Get)
        }
        receiver.start

        @w.start
        sleep 0.5

        receiver.stop
        received.should == true
      end
    end

    context "given create request" do
      before do
        header = Castoro::Protocol::UDPHeader.new '127.0.0.1', @mock_port, 0
        key    = Castoro::BasketKey.new(1, 2, 3)
        hints = { "class" => "original", "length" => 12345 }
        @create = Castoro::Protocol::Command::Create.new key, hints
        requests = [
          [ header, Castoro::Protocol::Command::Island.new('efc00101'.to_island, 1, 1000)  ],
          [ header, Castoro::Protocol::Command::Island.new('efc00102'.to_island, 2, 10000) ],
          [ header, Castoro::Protocol::Command::Island.new('efc00103'.to_island, 3, 20000) ],
          [ header, Castoro::Protocol::Command::Island.new('efc00104'.to_island, 4, 40000) ],
          [ header, Castoro::Protocol::Command::Island.new('efc00105'.to_island, 5, 60000) ],
          [ header, @create ],
        ]

        @facade.stub!(:recv).with(no_args).and_return { requests.shift }
      end

      it "should send multicast" do
        received = false
        receiver = Castoro::Receiver::UDP::Multicast.new(@logger, @port, 'efc00105'.to_island.to_ip, @device_addr) { |h,d,p,i|
          received = true if d.kind_of?(Castoro::Protocol::Command::Create)
        }
        receiver.start

        @w.start
        sleep 0.5

        receiver.stop
        received.should == true
      end
    end


    after do
      if @w
        @w.stop rescue nil
        @w = nil
      end
    end
  end
end

describe Castoro::Gateway::MasterWorkers::IslandStatus do
  before(:all) do
    @logger      = Logger.new(ENV['DEBUG'] ? STDOUT : nil)
    @device_addr = ENV['DEVICE']    || IPSocket.getaddress(Socket.gethostname)
    @port        = ENV['PORT']      || 30109
  end

  context "#choice_random" do
    before do
      key    = Castoro::BasketKey.new(1, 2, 3)
      hints = { "class" => "original", "length" => 12345 }
      @create = Castoro::Protocol::Command::Create.new key, hints
    end

    it "should choice random island" do
      islandStatus = Castoro::Gateway::MasterWorkers::IslandStatus.new @logger, @port, @device_addr
      islandStatus.start
      islandStatus.set Castoro::Protocol::Command::Island.new('efc00101'.to_island, 1, 1000)
      islandStatus.set Castoro::Protocol::Command::Island.new('efc00102'.to_island, 2, 10000)
      islandStatus.set Castoro::Protocol::Command::Island.new('efc00103'.to_island, 3, 20000)
      islandStatus.set Castoro::Protocol::Command::Island.new('efc00104'.to_island, 4, 40000)
      islandStatus.set Castoro::Protocol::Command::Island.new('efc00105'.to_island, 5, 60000)

      result = []
      1000.times {
        result.push(islandStatus.send(:choice_island, @create).to_s)
      }

      count = result.inject(Hash.new(0)){|hash, a| hash[a] +=1; hash }
      count["efc00105"].should >= 400
      count["efc00105"].should <= 600
      count["efc00104"].should >= 200
      count["efc00104"].should <= 400
      count["efc00103"].should >= 50
      count["efc00103"].should <= 200
    end
  end

end
