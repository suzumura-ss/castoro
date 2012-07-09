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

describe Castoro::Gateway::Workers do
  before do
    # mock for Logger
    @logger = mock(Logger)
    @logger.stub!(:info)
    @logger.stub!(:debug)
    @logger.stub!(:error)

    @header = mock(Castoro::Protocol::UDPHeader)
    @header.stub!(:to_s).and_return('["127.0.0.1",12345,1]' + "\r\n")
    @header.stub!(:ip).and_return("127.0.0.1")
    @header.stub!(:port).and_return(12345)

    # mock for Castoro::Gateway::Facade
    @facade = mock(Castoro::Gateway::Facade)

    # mock for Castoro::Gateway::Repository
    @repository = mock(Castoro::Gateway::Repository)

    # mock for Castoro::Sender::UDP::Multicast
    @sender = mock(Castoro::Sender::UDP::Multicast)
    Castoro::Sender::UDP::Multicast.stub!(:new).and_yield(@sender)
  end

  context "when the logger argument is omitted." do
    before do
      count   = 3
      mc_addr = "239.192.1.1"
      dv_addr = "127.0.0.1"
      port    = 12345

      @w = Castoro::Gateway::Workers.new(nil, count, @facade, @repository, mc_addr, dv_addr, port, nil)
    end

    it "should logger equals NilLogger" do
      l = @w.instance_variable_get :@logger
      l.should_not be_nil
      logdev = l.instance_variable_get :@logdev
      logdev.should be_nil
    end
  end

  context "When constructor argument is appropriately specified" do
    before do
      count   = 3
      mc_addr = "239.192.1.1"
      dv_addr = "127.0.0.1"
      port    = 12345

      @w = Castoro::Gateway::Workers.new(@logger, count, @facade, @repository, mc_addr, dv_addr, port, nil)
    end

    it "should be able start > stop > start ..." do
      @facade.stub!(:recv)
      100.times {
        @w.start
        @w.stop
      }
    end

    it "should alive? false" do
      @w.alive?.should be_false
    end

    context "When start" do
      it "should alive true" do
        @facade.stub!(:recv)
        @w.start
        @w.alive?.should be_true
      end

      it "should threads 3" do
        @facade.stub!(:recv)
        @w.start
        @w.instance_variable_get(:@threads).size.should == 3
      end

      it "should return 3 NOP responses to 3 NOP commands" do
        commands = [ [@header, Castoro::Protocol::Command::Nop.new] ] * 3
        @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

        @sender.should_receive(:send).
          exactly(3).
          with(@header, Castoro::Protocol::Response::Nop.new(nil), @header.ip, @header.port)

        @w.start
        sleep 1
      end

      it "should called update_watchdog_status to 4 ALIVE commands" do
        alive = Castoro::Protocol::Command::Alive.new("host", 30, 123456789)

        commands = [ [@header, alive] ] * 4
        @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

        @repository.should_receive(:update_watchdog_status).exactly(4).with(alive)

        @w.start
        sleep 1
      end

      it "should called drop_cache_record to 5 DROP commands" do
        key = Castoro::BasketKey.new(1, 2, 3)
        drop = Castoro::Protocol::Command::Drop.new(key, "host", "path")

        commands = [ [@header, drop] ] * 5
        @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

        @repository.should_receive(:drop_cache_record).exactly(5).with(drop)

        @w.start
        sleep 1
      end

      it "should called insert_cache_record to 6 INSERT commands" do
        key = Castoro::BasketKey.new(1, 2, 3)
        insert = Castoro::Protocol::Command::Insert.new(key, "host", "path")

        commands = [ [@header, insert] ] * 6
        @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

        @repository.should_receive(:insert_cache_record).exactly(6).with(insert)

        @w.start
        sleep 1
      end

      it "should execute fetch_available_peers and send the result to 7 CREATE commands" do
        key = Castoro::BasketKey.new(1, 2, 3)
        hints = { "class" => "original", "length" => 12345 }
        create = Castoro::Protocol::Command::Create.new(key, hints)

        commands = [ [@header, create] ] * 7
        @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

        fetch_result = "hoge"
        @repository.should_receive(:fetch_available_peers).
          exactly(7).
          with(create, nil).
          and_return(fetch_result)
        @sender.should_receive(:send).
          exactly(7).
          with(@header, fetch_result, @header.ip, @header.port)

        @w.start
        sleep 1
      end

      context "When 8 GET commands is received, and it doesn't exist in the cache" do
        it "should execute multicast to 8 GET commands" do
          key = Castoro::BasketKey.new(1, 2, 3)
          get = Castoro::Protocol::Command::Get.new(key)

          commands = [ [@header, get] ] * 8
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

          @repository.should_receive(:query).exactly(8).with(get).and_return(nil)
          @sender.should_receive(:multicast).exactly(8).with(@header, get)

          @w.start
          sleep 1
        end
      end

      context "When 8 GET commands is received, and it exist in the cache" do
        it "should execute query and send the result to 8 GET commands" do
          key = Castoro::BasketKey.new(1, 2, 3)
          get = Castoro::Protocol::Command::Get.new(key)

          commands = [ [@header, get] ] * 8
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

          query_result = "query result."
          @repository.should_receive(:query).exactly(8).with(get).and_return(query_result)
          @sender.should_receive(:send).
            exactly(8).
            with(@header, query_result, @header.ip, @header.port)

          @w.start
          sleep 1
        end
      end

      context "When the error occurs in worker loop" do
        it "should called @logger#error" do
          commands = [ [@header, Castoro::Protocol::Command::Nop.new] ] * 1
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }

          @sender.stub!(:send).exactly(3).and_return { raise "WORKER LOOP ERROR!!" }
          @logger.should_receive(:error).exactly(1)

          @w.start
          sleep 1
        end
      end

      context "When stop" do
        before do
          @w.start
          @w.stop
        end

        it "should alive? false" do
          @w.alive?.should be_false
        end

        it "should threads empty" do
	        @w.instance_variable_get(:@threads).should be_nil
        end
      end

    end

    after do
      @w.stop if @w.alive? rescue nil
      @w = nil
    end
  end

  context "given island id" do
    before do
      count   = 3
      mc_addr = "239.192.1.1"
      dv_addr = "127.0.0.1"
      port    = 12345
      @island = "ebcdef01".to_island

      @w = Castoro::Gateway::Workers.new(@logger, count, @facade, @repository, mc_addr, dv_addr, port, @island)
    end

    context "received CREATE command" do
      before do
        @create = Castoro::Protocol::Command::Create.new("1.2.3", { "class" => "original", "length" => 12345 })
        commands = [ [@header, @create] ] * 3
        @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
      end

      it "repository should receive #fetch_available_peers" do
        fetch_result = "hoge"
        @repository.should_receive(:fetch_available_peers).
          with(@create, @island).
          exactly(3).
          and_return(fetch_result)
        @sender.stub!(:send)

        @w.start
        sleep 1
      end
    end

    context "received GET command" do
      before do
        @sender.stub!(:send)
        @sender.stub!(:multicast)
      end

      context "when same island" do
        it "repository should receive #query with ('1.2.3', 'ebcdef01')" do
          get = Castoro::Protocol::Command::Get.new("1.2.3", @island)
          commands = [ [@header, get] ] * 3
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
          @repository.should_receive(:query).with(get).exactly(3)

          @w.start
          sleep 1
        end
      end

      context "when not same island" do
        it "repository should not receive #query" do
          get = Castoro::Protocol::Command::Get.new("1.2.3", "e2345678")
          commands = [ [@header, get] ]  * 3
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
          @repository.should_not_receive(:query)

          @w.start
          sleep 1
        end
      end

      context "when island is nil" do
        it "repository should receive #query with('1.2.3', 'ebcdef01')" do
          get = Castoro::Protocol::Command::Get.new("1.2.3", nil)
          commands = [ [@header, get] ]  * 3
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
          @repository.should_receive(:query).
            with(Castoro::Protocol::Command::Get.new("1.2.3", @island)).
            exactly(3)

          @w.start
          sleep 1
        end
      end
    end

    after do
      @w.stop if @w.alive? rescue nil
      @w = nil
    end
  end

  describe "follow up if replication is insufficient" do
    before do
      count   = 3
      mc_addr = "239.192.1.1"
      dv_addr = "127.0.0.1"
      port    = 12345
      @island = "ebcdef01".to_island

      @w = Castoro::Gateway::Workers.new(@logger, count, @facade, @repository, mc_addr, dv_addr, port, @island)
    end

    context "given less than the specified number peers(2/3)." do
      before do
        @sender.stub!(:send)
        @sender.stub!(:multicast)
        @repository.stub!(:query).and_return {}
        @repository.stub!(:if_replication_is_insufficient).and_yield()
      end

      context "when two peers." do
        it "should called if_replication_is_insufficient to 3 GET commands" do
          get = Castoro::Protocol::Command::Get.new("1.2.3", @island)
          commands = [ [@header, get] ] * 3
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
          res = Castoro::Protocol::Response::Get.new(false, "1.2.3",{"peer1"=>"/path", "peer2"=>"/path"},@island)
          @repository.should_receive(:query).with(get).exactly(3).and_return(res)
          @sender.should_receive(:send).
            exactly(3).
            with(@header, res, @header.ip, @header.port)
          @repository.should_receive(:if_replication_is_insufficient).with(res.paths.keys).exactly(3)

          @w.start
          sleep 1
        end

        it "sender should called multicast to 3 GET commands" do
          get = Castoro::Protocol::Command::Get.new("1.2.3", @island)
          commands = [ [@header, get] ] * 3
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
          res = Castoro::Protocol::Response::Get.new(false, "1.2.3",{"peer1"=>"/path", "peer2"=>"/path"},@island)
          @repository.should_receive(:query).with(get).exactly(3).and_return(res)
          @sender.should_receive(:multicast).with(@header, get).exactly(3)

          @w.start
          sleep 1
        end
      end

      after do
        @w.stop if @w.alive? rescue nil
        @w = nil
      end
    end

    context "given specified number peers(3/3)." do
      before do
        @sender.stub!(:send)
        @sender.stub!(:multicast)
        @repository.stub!(:query).and_return {}
        @repository.stub!(:if_replication_is_insufficient).and_yield()
        @repository.stub!(:if_replication_is_insufficient).with(["peer1", "peer2", "peer3"])
      end

      context "when three peers." do
        it "should not multicast to 3 GET commands." do
          evaluated = false
          get = Castoro::Protocol::Command::Get.new("1.2.3", @island)
          commands = [ [@header, get] ] * 3
          @facade.should_receive(:recv).at_least(1).and_return { commands.shift }
          res = Castoro::Protocol::Response::Get.new(false, "1.2.3",{"peer1"=>"/path", "peer2"=>"/path", "peer3"=>"/path"},@island)
          @repository.should_receive(:query).with(get).exactly(3).and_return(res)
          @sender.should_receive(:send).
            exactly(3).
            with(@header, res, @header.ip, @header.port)
          @sender.should_not_receive(:multicast)

          @w.start
          sleep 1
        end
      end
    end

    after do
      @w.stop if @w.alive? rescue nil
      @w = nil
    end
  end
end

