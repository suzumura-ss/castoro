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

describe Castoro::Gateway::Repository do
  before do
    @logger = Logger.new nil

    # test config
    @config = {
      "watchdog_limit" => 15,
    }

    # mock for Castoro::BasketCache
    @cache = mock Castoro::BasketCache
    @cache.stub! :watchdog_limit=
  end

  context "when constructor argument is appropriately specified" do
    before do
      Castoro::BasketCache.stub!(:new).with(@logger, @config).and_return @cache
    end

    it "should return Castoro::Gateway::Repository instance." do
      repository = Castoro::Gateway::Repository.new @logger, @config
      repository.should be_kind_of Castoro::Gateway::Repository
    end

    it "should be respond to query, fetch_available_peers, insert_cache_record, drop_cache_record, update_watchdog_status, status, dump." do
      repository = Castoro::Gateway::Repository.new @logger, @config
      repository.should respond_to :query, :fetch_available_peers, :insert_cache_record, :drop_cache_record, :update_watchdog_status, :status, :dump
    end

    it "should be set logger and cache." do
      repository = Castoro::Gateway::Repository.new @logger, @config
      repository.instance_variable_get(:@logger).should == @logger
      repository.instance_variable_get(:@cache).should  == @cache
    end

    context 'when query with cache find peer' do
      it "should return Castoro::Protocol::Response::Get instance." do
        key     = Castoro::BasketKey.new 1, 2, 3
        command = Castoro::Protocol::Command::Get.new key
        @cache.stub!(:find_by_key).with(key).and_return({"peer1"=>"path1/path2/path3"})
        repository = Castoro::Gateway::Repository.new @logger, @config

        res = repository.query command
        res.should be_kind_of Castoro::Protocol::Response::Get
        res.basket.should == key
        res.paths.should  == {"peer1"=>"path1/path2/path3"}
        res.error?.should be_false
      end
    end

    context "when query with cache not find peer" do
      it "should return nil." do
        key     = Castoro::BasketKey.new 1, 2, 3
        command = Castoro::Protocol::Command::Get.new key
        @cache.stub!(:find_by_key).with(key).and_return({})
        repository = Castoro::Gateway::Repository.new @logger, @config

        repository.query(command).should be_nil
      end
    end

    context "when fetch_available_peer from cache with no find peers." do
      it "should return error response." do
        key = Castoro::BasketKey.new 1, 2, 3
        command = Castoro::Protocol::Command::Create.new key, {"class" => :original, "length" => 100}
        @cache.stub!(:preferentially_find_peers).with({"class" => "original", "length" => 100}).and_return([])
        repository = Castoro::Gateway::Repository.new @logger, @config

        res = repository.fetch_available_peers command, "abcdef01"
        res.should be_kind_of Castoro::Protocol::Response::Create::Gateway
        res.error?.should be_true
      end
    end

    context "when fetch availabele_peer from cache with find peers." do
      context "given island 'ebcdef01'" do
        it "should return Castoro::Response::Create::Gateway instance that contains the Peers." do
          @cache.stub!(:preferentially_find_peers)
            .with({"class" => "original", "length" => 100})
            .and_return(["host1", "host2", "host3"])
          key = Castoro::BasketKey.new 1, 2, 3
          command = Castoro::Protocol::Command::Create.new key, {"class" => :original, "length" => 100}
          repository = Castoro::Gateway::Repository.new @logger, @config

          res = repository.fetch_available_peers command, "ebcdef01"
          res.should be_kind_of Castoro::Protocol::Response::Create::Gateway
          res.error?.should be_false
          res.basket.should == key
          res.island.should == "ebcdef01".to_island
          res.hosts.should  == ["host1", "host2", "host3"]
        end
      end

      context "given island 'e2345678'" do
        it "should set 'e2345678' to response#island" do
          @cache.stub!(:preferentially_find_peers)
            .with({"class" => "original", "length" => 100})
            .and_return(["host1", "host2", "host3"])
          key = Castoro::BasketKey.new 1, 2, 3
          command = Castoro::Protocol::Command::Create.new key, {"class" => :original, "length" => 100}
          repository = Castoro::Gateway::Repository.new @logger, @config

          res = repository.fetch_available_peers command, "e2345678"
          res.should be_kind_of Castoro::Protocol::Response::Create::Gateway
          res.error?.should be_false
          res.basket.should == key
          res.island.should == "e2345678".to_island
          res.hosts.should  == ["host1", "host2", "host3"]
        end
      end

      context "given island nil" do
        it "should not set response#island" do
          @cache.stub!(:preferentially_find_peers)
            .with({"class" => "original", "length" => 100})
            .and_return(["host1", "host2", "host3"])
          key = Castoro::BasketKey.new 1, 2, 3
          command = Castoro::Protocol::Command::Create.new key, {"class" => :original, "length" => 100}
          repository = Castoro::Gateway::Repository.new @logger, @config

          res = repository.fetch_available_peers command, nil
          res.should be_kind_of Castoro::Protocol::Response::Create::Gateway
          res.error?.should be_false
          res.basket.should == key
          res.island.should == nil
          res.hosts.should  == ["host1", "host2", "host3"]
        end
      end
    end

    context "when insert cache record" do
      it "cache#insert should be called once." do
        @cache.stub!(:insert)
        key = Castoro::BasketKey.new 1, 2, 3
        command = Castoro::Protocol::Command::Insert.new key, "host", "path1/path2/path3/path4/path5"
        @cache.should_receive(:insert).with(key, "host").exactly(1)

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.insert_cache_record command
      end
    end

    context "when drop cache record from command" do
      it "cache#erase_by_peer_and_key should be called once." do
        key = Castoro::BasketKey.new 1, 2, 3
        command = Castoro::Protocol::Command::Drop.new key, "host", "path"

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.should_receive(:drop).with(command.basket, command.host).exactly(1)
        repository.drop_cache_record command
      end
    end

    context "when drop cache record" do
      it "cache#erase_by_peer_and_key should be called once." do
        @cache.stub!(:erase_by_peer_and_key)
        key = Castoro::BasketKey.new 1, 2, 3
        command = Castoro::Protocol::Command::Drop.new key, "host", "path"
        @cache.should_receive(:erase_by_peer_and_key).with("host", key).exactly(1)

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.drop_cache_record command
      end
    end

    context "when update watchdog status" do
      it "cache#set_status should be called once." do
        @cache.stub!(:set_status)
        command = Castoro::Protocol::Command::Alive.new "host", 30, 100
        @cache.should_receive(:set_status).with("host", 30, 100).exactly(1)

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.update_watchdog_status command
      end
    end

    context "when get cache status" do
      it "cache#status should be called once." do
        @cache.stub!(:status)
        @cache.should_receive(:status).exactly(1)

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.status
      end
    end

    context "when get peersStatus" do
      it "cache#get_peers_info should be called once." do
        @cache.stub!(:peers_status).and_return({"peer1"=> {:status=>10, :available=>1000}, "peer2"=>{:status=>20, :available=>1100},"peer3"=>{:status=>30, :available=>1200}});
        @cache.should_receive(:peers_status).exactly(1)

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.peers_status.should == {"peer1"=> {:status=>10, :available=>1000}, "peer2"=>{:status=>20, :available=>1100},"peer3"=>{:status=>30, :available=>1200}}
      end
    end 

    context "when dump the cache" do
      it "cache#dump should be called once." do
        @cache.stub!(:dump)
        io = STDOUT
        @cache.should_receive(:dump).with(io, "peer1").exactly(1)

        repository = Castoro::Gateway::Repository.new @logger, @config
        repository.dump io, "peer1"
      end
    end

    describe "multicast expectation" do
      before do
        @config["replication_count"] = 3
        @cache.stub!(:active_peer_count).and_return(15)
        @cache.stub!(:available_total_space).and_return(123456789)
        @cache.stub!(:all_active?).with(["peer1","peer2"]).and_return(false)
        @cache.stub!(:all_active?).with(["peer1","peer2","peer3"]).and_return(false)
        @cache.stub!(:all_active?).with(["peer2","peer3","peer4"]).and_return(true)
        @cache.stub!(:all_active?).with(["peer2","peer3"]).and_return(true)
      end

      context "when get storable peers." do
        it "should get storables." do
          repository = Castoro::Gateway::Repository.new @logger, @config
          repository.storables.should == 15
        end
      end

      context "when get capacity total space of peers." do
        it "should get capacity." do
          repository = Castoro::Gateway::Repository.new @logger, @config
          repository.capacity.should == 123456789
        end
      end

      context "when replication is insufficient." do
        it "should not evaluate yield (peers.size more than replication_count)." do
          evaluated = false
          repository = Castoro::Gateway::Repository.new @logger, @config
          peers = ["peer1","peer2", "peer3"]
          repository.if_replication_is_insufficient(peers) { evaluated = true }
          evaluated.should == false
        end

        it "should not evaluate yield (peers.size more than replication_count & cache active)." do
          evaluated = false
          repository = Castoro::Gateway::Repository.new @logger, @config
          peers = ["peer2","peer3", "peer4"]
          repository.if_replication_is_insufficient(peers) { evaluated = true }
          evaluated.should == false
        end

        it "should not evaluate yield (peers.size less than replication_count)." do
          evaluated = false
          repository = Castoro::Gateway::Repository.new @logger, @config
          peers = ["peer1","peer2"]
          repository.if_replication_is_insufficient(peers) { evaluated = true }
          evaluated.should == false
        end

        it "should evaluate yield." do
          evaluated = false
          repository = Castoro::Gateway::Repository.new @logger, @config
          peers = ["peer2","peer3"]
          repository.if_replication_is_insufficient(peers) { evaluated = true }
          peers.size.should < @config["replication_count"]
          evaluated.should == true
        end
      end
    end
  end
end
