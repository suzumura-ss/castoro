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

require File.join(File.dirname(__FILE__), '../cache.so')

PEER1 = "std100"; BASE1="/expdsk/baskets/r"
PEER2 = "std101"; BASE2="/expdsk/baskets/w"
PEER3 = "std102"; BASE3="/expdsk/baskets/a"
ACTIVE = { :status => Castoro::Cache::Peer::ACTIVE, :available => 10*1000*1000*1000 }
ACTIVE_100 = { :status => Castoro::Cache::Peer::ACTIVE, :available => 100 }
ACTIVE_1000 = { :status => Castoro::Cache::Peer::ACTIVE, :available => 1000 }
READONLY = { :status => Castoro::Cache::Peer::READONLY }
MAINTENANCE = { :status => Castoro::Cache::Peer::MAINTENANCE }


def buildpath(p, b, c, t, r)
  k = c / 1000
  m, k = k.divmod 1000
  g, m = m.divmod 1000
  "%s:%s/%d/%03d/%03d/%d.%d.%d"%[p, b, g, m, k, c, t, r]
end

def nfs1(c, t, r); buildpath PEER1, BASE1, c, t, r; end
def nfs2(c, t, r); buildpath PEER2, BASE2, c, t, r; end
def nfs3(c, t, r); buildpath PEER3, BASE3, c, t, r; end

def check_range this, id, expr
  this.peers[PEER1].insert(id,0,0,BASE1)
  this.find(id,0,0)[0].should =~ expr
  this.peers[PEER1].insert(id+999,0,0,BASE1)
  this.find(id+999,0,0)[0].should =~ expr
end


describe Castoro::Cache do
  context "when initialize" do
    it "should be raise exception when page = 0" do
      lambda{ c = Castoro::Cache.new(0) }.should raise_error(ArgumentError)
    end
    it "should be raise exception when pages < 0" do
      lambda{ c = Castoro::Cache.new(-1) }.should raise_error(ArgumentError)
    end
    it "should be success when pages >0" do
      Castoro::Cache.new(1).should_not be_nil
    end
  end

  context "when empty" do
    before do
      @cache = Castoro::Cache.new(10)
    end

    it "should be empty" do
      @cache.find(1,2,3).should be_empty
    end

    after do
      @cache = nil
    end
  end


  context "when insert a item" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].insert(1,2,3,BASE1)
    end

    it "should be empty when insert and remove it" do
      @cache.peers[PEER1].erase(1,2,3)
      @cache.find(1,2,3).should be_empty
    end

    it "should be empty when insert but NOT activated" do
      @cache.find(1,2,3).should be_empty
    end

    it "should be one item when mark active" do
      @cache.peers[PEER1].status = ACTIVE
      @cache.find(1,2,3).should == [nfs1(1,2,3)]
    end

    it "should be one item when mark readonly" do
      @cache.peers[PEER1].status = READONLY
      @cache.find(1,2,3).should == [nfs1(1,2,3)]
    end

    it "should be empty when mark maintenance" do
      @cache.peers[PEER1].status = MAINTENANCE
      @cache.find(1,2,3).should be_empty
    end

    after do
      @cache = nil
    end
  end

  context "when insert a very big id item" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].insert(0xffffffffffffffff0123456789abcdef, 2, 3, BASE1)
    end

    it "should be empty when insert and remove it" do
      @cache.peers[PEER1].erase(0xffffffffffffffff0123456789abcdef,2,3)
      @cache.find(0xffffffffffffffff0123456789abcdef,2,3).should be_empty
    end

    it "should be empty when insert but NOT activated" do
      @cache.find(0xffffffffffffffff0123456789abcdef,2,3).should be_empty
    end

    it "should be one item when mark active" do
      @cache.peers[PEER1].status = ACTIVE
      @cache.find(0xffffffffffffffff0123456789abcdef,2,3).should == [nfs1(0xffffffffffffffff0123456789abcdef,2,3)]
    end

    it "should be one item when mark readonly" do
      @cache.peers[PEER1].status = READONLY
      @cache.find(0xffffffffffffffff0123456789abcdef,2,3).should == [nfs1(0xffffffffffffffff0123456789abcdef,2,3)]
    end

    it "should be empty when mark maintenance" do
      @cache.peers[PEER1].status = MAINTENANCE
      @cache.find(0xffffffffffffffff0123456789abcdef,2,3).should be_empty
    end

    after do
      @cache = nil
    end
  end

  context "when insert 2 items into same peer" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].insert(1,2,3,BASE1)
      @cache.peers[PEER1].insert(4,5,6,BASE1)
    end

    it "should be empty when insert, but NOT activated" do
      @cache.find(1,2,3).should be_empty
      @cache.find(4,5,6).should be_empty
    end

    it "should be one item when and mark active" do
      @cache.peers[PEER1].status = ACTIVE
      @cache.find(1,2,3).should == [nfs1(1,2,3)]
      @cache.find(4,5,6).should == [nfs1(4,5,6)]
    end

    it "should be empty when mark readonly" do
      @cache.peers[PEER1].status = READONLY
      @cache.find(1,2,3).should == [nfs1(1,2,3)]
      @cache.find(4,5,6).should == [nfs1(4,5,6)]
    end

    it "should be empty when mark maintenance" do
      @cache.peers[PEER1].status = MAINTENANCE
      @cache.find(1,2,3).should be_empty
      @cache.find(4,5,6).should be_empty
    end

    after do
      @cache = nil
    end
  end


  context "when insert 2 items into different peers" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].insert(1,2,3,BASE1)
      @cache.peers[PEER2].insert(1,2,3,BASE2)
    end

    it "should be empty when insert, but NOT activated" do
      @cache.find(1,2,3).should be_empty
    end

    it "should be one item when mark active one" do
      @cache.peers[PEER1].status = ACTIVE
      @cache.find(1,2,3).should == [nfs1(1,2,3)]
    end

    context "-> activated" do
      before do
        @cache.peers[PEER1].status = ACTIVE
        @cache.peers[PEER2].status = ACTIVE
      end
        
      it "should be two items mark active all" do
        @cache.find(1,2,3).should == [nfs1(1,2,3),nfs2(1,2,3)]
      end

      it "should be empty when mark readonly" do
        @cache.peers[PEER1].status = READONLY
        @cache.find(1,2,3).should == [nfs1(1,2,3),nfs2(1,2,3)]
        @cache.peers[PEER2].status = READONLY
        @cache.find(1,2,3).should == [nfs1(1,2,3),nfs2(1,2,3)]
      end

      it "should be empty when mark maintenance" do
        @cache.peers[PEER1].status = MAINTENANCE
        @cache.find(1,2,3).should == [nfs2(1,2,3)]
        @cache.peers[PEER2].status = MAINTENANCE
        @cache.find(1,2,3).should be_empty
      end
    end

    after do
      @cache = nil
    end
  end


  context "when remove item" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].insert(1,2,3,BASE1)
      @cache.peers[PEER2].insert(1,2,3,BASE2)
      @cache.peers[PEER3].insert(1,2,3,BASE3)
      @cache.peers[PEER1].status = ACTIVE
      @cache.peers[PEER2].status = ACTIVE
      @cache.peers[PEER3].status = ACTIVE
      @cache.peers[PEER1].insert(2,2,3,BASE1)
    end

    it "should be found 3 peers when remove unknown item" do
      @cache.peers["unknown"].erase(1,2,3)
      @cache.find(1,2,3).should == [nfs1(1,2,3),nfs2(1,2,3),nfs3(1,2,3)]
    end

    it "should be found 2 peer when remove 1 item" do
      @cache.peers[PEER3].erase(1,2,3)
      @cache.find(1,2,3).should == [nfs1(1,2,3),nfs2(1,2,3)]
    end

    it "should be found 2 peer when remove 1 item" do
      @cache.peers[PEER2].erase(1,2,3)
      @cache.peers[PEER3].erase(1,2,3)
      @cache.find(1,2,3).should == [nfs1(1,2,3)]
    end

    it "should be found no peers when remove all." do
      @cache.peers[PEER1].erase(1,2,3)
      @cache.peers[PEER2].erase(1,2,3)
      @cache.peers[PEER3].erase(1,2,3)
      @cache.find(1,2,3).should == nil
    end

    after do
      @cache = nil
    end
  end

  context "peers matching" do
    before do
      @cache = Castoro::Cache.new(10)
    end

    it "should empty when there is no peers." do
      @cache.peers.find(0).should be_empty
    end

    context "there is 2 peers, there are 100 and 1000 bytes writable" do
      before do
        @cache.peers[PEER1].status = ACTIVE_100
        @cache.peers[PEER2].status = ACTIVE_1000
      end

      it "should be include 2(all) peers when argument is omitted" do
        @cache.peers.find.should == [PEER1, PEER2]
      end

      it "should be include 2 peers when require 50 bytes" do
        @cache.peers.find(50).should == [PEER1, PEER2]
      end

      it "should be include 1 peers when require 500 bytes" do
        @cache.peers.find(500).should == [PEER2]
      end

      it "should empty when require 5000 bytes" do
        @cache.peers.find(5000).should be_empty
      end
    end

    context "there is 2 peers, there are 100 bytes writable and 1000 bytes avail but readonly" do
      before do
        @cache.peers[PEER1].status = ACTIVE_100
        @cache.peers[PEER2].status = ACTIVE_1000
        @cache.peers[PEER2].status = READONLY
      end

      it "should be include 2(all) peers when argument is omitted" do
        @cache.peers.find.should == [PEER1, PEER2]
      end

      it "should be include 1 peer when require 50 bytes" do
        @cache.peers.find(50).should == [PEER1]
      end

      it "should empty when be include 1 peers when require 500 bytes" do
        @cache.peers.find(500).should be_empty
      end

      it "should empty when require 5000 bytes" do
        @cache.peers.find(5000).should be_empty
      end
    end

    after do
      @cache = nil
    end
  end

  context "when content id is large" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].status = ACTIVE
    end

    it "part of path should be '/0/000/000/' when id < 1000" do
      check_range @cache, 0, %r{/0/000/000/}
    end

    it "part of path should be '/0/000/001/' when 1000<= id <=1999" do
      check_range @cache, 1*1000, %r{/0/000/001/}
    end

    it "part of path should be '/0/000/999/' when 999,000<= id <=999,999" do
      check_range @cache, 999*1000, %r{/0/000/999/}
    end

    it "part of path should be '/0/001/000/' when 1,000,000<= id <=1,000,999" do
      check_range @cache, 1*1000*1000, %r{/0/001/000/}
    end

    it "part of path should be '/0/999/000/' when 999,000,000<= id <=999,000,999" do
      check_range @cache, 999*1000*1000, %r{/0/999/000/}
    end

    it "part of path should be '/1/000/000/' when 1,000,000,000<= id <=1,000,000,999" do
      check_range @cache, 1*1000*1000*1000, %r{/1/000/000/}
    end

    it "part of path should be '/1000/000/000/' when 1,000,000,000,000<= id <=1,000,000,000,999" do
      check_range @cache, 1000*1000*1000*1000, %r{/1000/000/000/}
    end

    after do
      @cache = nil
    end
  end


  context "when make_nfs_path is overloaded" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].status = ACTIVE
      class << @cache
        def make_nfs_path(p, b, c, t, r)
          {:host=>p.to_s, :path=>"#{b}/#{c}.#{t}@#{r}"}
        end
      end
    end

    it "path should be 'peer:/base/cid.type@rev'" do
      @cache.peers[PEER1].insert(1,2,3,BASE1)
      @cache.find(1,2,3).should == [{:host=>PEER1, :path=>"#{BASE1}/1.2@3"}]
    end

    after do
      @cache = nil
    end
  end


  context "watchdog expires" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.watchdog_limit = 1
      @cache.peers[PEER1].insert(1,2,3,BASE1)
      @cache.peers[PEER2].insert(1,2,3,BASE2)
    end

    it "should be include peer1, peer2" do
      @cache.peers[PEER1].status = ACTIVE
      @cache.peers[PEER2].status = ACTIVE
      @cache.find(1,2,3).should == [nfs1(1,2,3),nfs2(1,2,3)]
    end
    
    it "should not be include peer1 when timeout" do
      @cache.peers[PEER1].status = ACTIVE
      @cache.peers[PEER2].status = ACTIVE
      sleep 2.0
      @cache.peers[PEER2].status = ACTIVE
      @cache.find(1,2,3).should == [nfs2(1,2,3)]
    end

    describe "#watchdog_limit" do
      it "should be eql 1" do
        @cache.watchdog_limit.should be_eql 1
      end
    end

    after do
      @cache = nil
    end
  end


  context "dump cache" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.peers[PEER1].insert(0x0123456789abcdef0123456789abcdef,2,3,BASE1)
      @cache.peers[PEER2].insert(1,2,3,BASE2)
      @cache.peers[PEER3].insert(1,2,3,BASE3)
      @cache.peers[PEER1].status = ACTIVE
      @cache.peers[PEER2].status = READONLY
      @cache.peers[PEER3].status = MAINTENANCE
    end

    it "should be dump" do
      result = ""
      class << result
        def puts(str)
          self << str + "\n"
        end
      end
      @cache.dump(result).should be_true
      result.should == <<__RESULT__
  std101: /expdsk/baskets/w/1.2.3
  std102: /expdsk/baskets/a/1.2.3
  std100: /expdsk/baskets/r/#{0x0123456789abcdef0123456789abcdef}.2.3
__RESULT__
    end

    after do
      @cache = nil
    end
  end


  context "cache stat" do
    before do
      @cache = Castoro::Cache.new(10)
      @cache.watchdog_limit = 5
      @cache.peers[PEER1].insert(1,2,3,BASE1)
      @cache.peers[PEER2].insert(1,2,3,BASE2)
      @cache.peers[PEER1].status = ACTIVE
      @cache.peers[PEER2].status = READONLY
      @cache.find(1,2,3)
      @cache.find(4,5,6)
    end

    describe "#watchdog_limit" do
      it "should be eql 1" do
        @cache.watchdog_limit.should be_eql 5
      end
    end

    it "should return stats" do
      @cache.stat(Castoro::Cache::DSTAT_CACHE_EXPIRE).should == 5
      @cache.stat(Castoro::Cache::DSTAT_CACHE_REQUESTS).should == 2
      @cache.stat(Castoro::Cache::DSTAT_CACHE_HITS).should == 1
      @cache.stat(Castoro::Cache::DSTAT_CACHE_COUNT_CLEAR).should == 500
      @cache.stat(Castoro::Cache::DSTAT_ALLOCATE_PAGES).should == 10
      @cache.stat(Castoro::Cache::DSTAT_FREE_PAGES).should == 9
      @cache.stat(Castoro::Cache::DSTAT_ACTIVE_PAGES).should == 1
      @cache.stat(Castoro::Cache::DSTAT_HAVE_STATUS_PEERS).should == 2
      @cache.stat(Castoro::Cache::DSTAT_ACTIVE_PEERS).should == 1
      @cache.stat(Castoro::Cache::DSTAT_READABLE_PEERS).should == 2
    end

    after do
      @cache = nil
    end
  end
end
