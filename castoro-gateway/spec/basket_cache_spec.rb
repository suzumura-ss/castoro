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

available   = 10*1000*1000*1000
ACTIVE      = Castoro::Cache::Peer::ACTIVE
READONLY    = Castoro::Cache::Peer::READONLY
MAINTENANCE = Castoro::Cache::Peer::MAINTENANCE

keys = [
  Castoro::BasketKey.new(291, :bitmap, 3),
  Castoro::BasketKey.new(4567890, :bitmap, 2),
  Castoro::BasketKey.new(1357902, :original, 3),
]

CACHE_SETTINGS = {
  "watchdog_limit" => 15,
  "return_peer_number" => 5,
  "cache_size" => 500000,
  "filter"=> "
      Proc.new { |available_peers, klass|
        klass = 'default' if klass.nil?
        storeables = case klass
                     when 'class1'
                       ['peer100', 'peer101']
                     when 'class2'
                       ['peer102', 'peer103']
                     when 'default'
                       ['peer100', 'peer101', 'peer102', 'peer103', 'peer104']
                     else
                       []
                     end
        available_peers.select{ |peer|
          storeables.include?(peer)
        }
      }",
  "basket_basedir" => "/expdsk",
  "basket_keyconverter" => {
    "Dec40Seq" => "0-65535",
    "Hex64Seq" => "",
  },  
}


describe Castoro::BasketCache do

  context "when empty" do
    before do
      logger = Logger.new nil
      @cache = Castoro::BasketCache.new logger, CACHE_SETTINGS

      @cache.set_status "peer100", ACTIVE, available
    end

    it "should be empty." do
      @cache.find_by_key(keys[1]).should be_empty
    end

    it "should return the status of the cache initialization." do
      res = @cache.status
      res.should be_kind_of Hash
      res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
      res[:CACHE_REQUESTS].should          == 0
      res[:CACHE_HITS].should              == 0
      res[:CACHE_COUNT_CLEAR].should       == 0
      res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
      res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
      res[:CACHE_ACTIVE_PAGES].should      == 0 
      res[:CACHE_HAVE_STATUS_PEERS].should == 1
      res[:CACHE_ACTIVE_PEERS].should      == 1
      res[:CACHE_READABLE_PEERS].should    == 1
    end

    it "dump result should be empty." do
      io = StringIO.new
      @cache.dump io
      io.rewind
      io.read.should == "\n"
    end

    after do
      @cache = nil
    end
  end

  context "when insert items" do
    before do
      logger = Logger.new nil
      @cache = Castoro::BasketCache.new logger, CACHE_SETTINGS

      @cache.insert(keys[0], "peer100")
      @cache.insert(keys[1], "peer101")
      @cache.insert(keys[2], "peer102")
    end

    it "should be changed the status of the page size." do
      res = @cache.status
      res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
      res[:CACHE_REQUESTS].should          == 0
      res[:CACHE_HITS].should              == 0
      res[:CACHE_COUNT_CLEAR].should       == 0
      res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
      res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE - res[:CACHE_ACTIVE_PAGES]
      res[:CACHE_ACTIVE_PAGES].should      == 3 
      res[:CACHE_HAVE_STATUS_PEERS].should == 0
      res[:CACHE_ACTIVE_PEERS].should      == 0
      res[:CACHE_READABLE_PEERS].should    == 0
    end

    it "dump result should be inserted items." do
      io = StringIO.new
      @cache.dump io
      io.rewind
      io.read.split("\n").size.should == 3
      io.rewind
      io.read.should == "  peer102: 1357902.0.3\n  peer101: 4567890.1.2\n  peer100: 291.1.3\n\n"
    end

    context "and remove it with 1 storage is active" do
      before do
        @cache.set_status "peer100", ACTIVE, available
        @cache.erase_by_peer_and_key("peer100", keys[0])
        @cache.erase_by_peer_and_key("peer101", keys[1])
        @cache.erase_by_peer_and_key("peer102", keys[2])
      end
      
      it "should be erased items." do
        @cache.find_by_key(keys[0]).should be_empty
        @cache.find_by_key(keys[1]).should be_empty
        @cache.find_by_key(keys[2]).should be_empty
      end

      it "#status return the number of miss hits after #find_by_key." do
        @cache.find_by_key(keys[0])
        @cache.find_by_key(keys[1])
        @cache.find_by_key(keys[2])

        res = @cache.status
        res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
        res[:CACHE_REQUESTS].should          == 3
        res[:CACHE_HITS].should              == 0
        res[:CACHE_COUNT_CLEAR].should       == 0
        res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_ACTIVE_PAGES].should      == 0 
        res[:CACHE_HAVE_STATUS_PEERS].should == 1
        res[:CACHE_ACTIVE_PEERS].should      == 1
        res[:CACHE_READABLE_PEERS].should    == 1
      end
    
      it "dump result should be empty." do
        io = StringIO.new
        @cache.dump io
        io.rewind
        io.read.should == "\n"
      end
    end

    context "with storage status is nothing" do
      it "should not be able to find inserted items." do
        @cache.find_by_key(keys[0]).should be_empty
        @cache.find_by_key(keys[1]).should be_empty
        @cache.find_by_key(keys[2]).should be_empty
      end
  
      it "#status return the number of miss hits after #find_by_key." do
        @cache.find_by_key(keys[0])
        @cache.find_by_key(keys[1])
        @cache.find_by_key(keys[2])

        res = @cache.status
        res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
        res[:CACHE_REQUESTS].should          == 3
        res[:CACHE_HITS].should              == 0
        res[:CACHE_COUNT_CLEAR].should       == 0
        res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE - res[:CACHE_ACTIVE_PAGES]
        res[:CACHE_ACTIVE_PAGES].should      == 3 
        res[:CACHE_HAVE_STATUS_PEERS].should == 0
        res[:CACHE_ACTIVE_PEERS].should      == 0
        res[:CACHE_READABLE_PEERS].should    == 0
      end

      it "#peersStatus return the zero available and status." do
        res = @cache.peersStatus
        res.should == []
      end

    end

    context 'with all storage status is active' do
      before do
        @cache.set_status "peer100", ACTIVE, available
        @cache.set_status "peer101", ACTIVE, available
        @cache.set_status "peer102", ACTIVE, available
      end

      it "should be able to find the inserted items." do
        @cache.find_by_key(keys[0]).should == {
            "peer100" => "/expdsk/1/baskets/a/0/000/000/291.1.3",
        }
        @cache.find_by_key(keys[1]).should == {
            "peer101" => "/expdsk/1/baskets/a/0/004/567/4567890.1.2",
        }
        @cache.find_by_key(keys[2]).should == {
            "peer102" => "/expdsk/0/baskets/a/0/001/357/1357902.0.3",
        }
      end

      it "#status return the number of miss hits after #find_by_key." do
        @cache.find_by_key(keys[0])
        @cache.find_by_key(keys[1])
        @cache.find_by_key(keys[2])

        res = @cache.status
        res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
        res[:CACHE_REQUESTS].should          == 3
        res[:CACHE_HITS].should              == 3
        res[:CACHE_COUNT_CLEAR].should       == 1000
        res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE - res[:CACHE_ACTIVE_PAGES]
        res[:CACHE_ACTIVE_PAGES].should      == 3 
        res[:CACHE_HAVE_STATUS_PEERS].should == 3
        res[:CACHE_ACTIVE_PEERS].should      == 3
        res[:CACHE_READABLE_PEERS].should    == 3
      end

      it "#peersStatus return the available and active status" do
        res = @cache.peersStatus
        res[0][0].should == "peer100"
        res[0][1].should == ACTIVE
        res[0][2].should == available 
        res[1][0].should == "peer101"
        res[1][1].should == ACTIVE
        res[1][2].should == available 
        res[2][0].should == "peer102"
        res[2][1].should == ACTIVE
        res[2][2].should == available
      end
    end

    context 'with storage status is read only' do
      before do
        @cache.set_status "peer100", READONLY, available
        @cache.set_status "peer101", READONLY, available
        @cache.set_status "peer102", READONLY, available
      end

      it "should be found the insert items." do
        @cache.find_by_key(keys[0]).should == {
          "peer100" => "/expdsk/1/baskets/a/0/000/000/291.1.3",
        }
        @cache.find_by_key(keys[1]).should == {
          "peer101" => "/expdsk/1/baskets/a/0/004/567/4567890.1.2",
        }
        @cache.find_by_key(keys[2]).should == {
          "peer102" => "/expdsk/0/baskets/a/0/001/357/1357902.0.3",
        }
      end

      it "#status return the number of hits after #find_by_key." do
        @cache.find_by_key(keys[0])
        @cache.find_by_key(keys[1])
        @cache.find_by_key(keys[2])

        res = @cache.status
        res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
        res[:CACHE_REQUESTS].should          == 3
        res[:CACHE_HITS].should              == 3
        res[:CACHE_COUNT_CLEAR].should       == 1000
        res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE - res[:CACHE_ACTIVE_PAGES]
        res[:CACHE_ACTIVE_PAGES].should      == 3 
        res[:CACHE_HAVE_STATUS_PEERS].should == 3
        res[:CACHE_ACTIVE_PEERS].should      == 0
        res[:CACHE_READABLE_PEERS].should    == 3
      end

      it "#peersStatus return the available and readonly status" do
        res = @cache.peersStatus
        res[0][0].should == "peer100"
        res[0][1].should == READONLY 
        res[0][2].should == available
        res[1][0].should == "peer101"
        res[1][1].should == READONLY 
        res[1][2].should == available
        res[2][0].should == "peer102"
        res[2][1].should == READONLY
        res[2][2].should == available
      end
    end

    context 'with storage status is maintenance' do
      before do
        @cache.set_status "peer100", MAINTENANCE, available
        @cache.set_status "peer101", MAINTENANCE, available
        @cache.set_status "peer102", MAINTENANCE, available
      end
  
      it "should not be able to find the inserted items." do
        @cache.find_by_key(keys[0]).should be_empty
        @cache.find_by_key(keys[1]).should be_empty
        @cache.find_by_key(keys[2]).should be_empty
      end

      it "#status return the number of miss hits after #find_by_key." do
        @cache.find_by_key(keys[0])
        @cache.find_by_key(keys[1])
        @cache.find_by_key(keys[2])

        res = @cache.status
        res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
        res[:CACHE_REQUESTS].should          == 3
        res[:CACHE_HITS].should              == 0
        res[:CACHE_COUNT_CLEAR].should       == 0
        res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE - res[:CACHE_ACTIVE_PAGES]
        res[:CACHE_ACTIVE_PAGES].should      == 3 
        res[:CACHE_HAVE_STATUS_PEERS].should == 3
        res[:CACHE_ACTIVE_PEERS].should      == 0
        res[:CACHE_READABLE_PEERS].should    == 0
      end

      it "#peersStatus return the available and maintenance status" do
        res = @cache.peersStatus
        res[0][0].should == "peer100"
        res[0][1].should == MAINTENANCE 
        res[0][2].should == available
        res[1][0].should == "peer101"
        res[1][1].should == MAINTENANCE 
        res[1][2].should == available
        res[2][0].should == "peer102"
        res[2][1].should == MAINTENANCE
        res[2][2].should == available
      end
    end

    after do
      @cache = nil
    end
  end

  context "peers matching" do
    before do
      logger = Logger.new nil
      @cache = Castoro::BasketCache.new logger, CACHE_SETTINGS
    end

    it "should empty when there is no peers." do
      @cache.find_peers({"length" => 0}).should be_empty
      @cache.preferentially_find_peers({"length" => 0}).should be_empty
    end

    context "there are 3 peers, 100 and 1000 bytes writable class1 and 1000 bytes writable class2" do
      before do
        @cache.set_status "peer100", ACTIVE, 100
        @cache.set_status "peer101", ACTIVE, 1000
        @cache.set_status "peer102", ACTIVE, 1000
      end

      it "#status should return values that reflect of the 3 peers status." do
        res = @cache.status
        res[:CACHE_EXPIRE].should            == CACHE_SETTINGS["watchdog_limit"]
        res[:CACHE_REQUESTS].should          == 0
        res[:CACHE_HITS].should              == 0
        res[:CACHE_COUNT_CLEAR].should       == 0
        res[:CACHE_ALLOCATE_PAGES].should    == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE
        res[:CACHE_FREE_PAGES].should        == CACHE_SETTINGS["cache_size"] / Castoro::Cache::PAGE_SIZE - res[:CACHE_ACTIVE_PAGES]
        res[:CACHE_ACTIVE_PAGES].should      == 0 
        res[:CACHE_HAVE_STATUS_PEERS].should == 3
        res[:CACHE_ACTIVE_PEERS].should      == 3
        res[:CACHE_READABLE_PEERS].should    == 3
      end

      it "should be used default class and included 3 peers when require 50 bytes and without class." do
        @cache.find_peers({"length" => 50}) =~ ["peer100","peer101","peer102"]
        @cache.preferentially_find_peers({"length" => 50}) =~ ["peer100","peer101","peer102"]
      end

      it "should be included 2 peers when require 50 bytes and class = class1." do
        @cache.find_peers({"length" => 50, "class" => "class1"}) =~ ["peer100","peer101"]
        @cache.preferentially_find_peers({"length" => 50, "class" => "class1"}) =~ ["peer100","peer101"]
      end

      it "should be included 1 peer when require class = class2." do
        @cache.find_peers({"class" => "class2"}) =~ ["peer102"]
        @cache.preferentially_find_peers({"class" => "class2"})=~ ["peer102"]
      end

      it "should be included 1 peers when require 500 bytes and class = class1." do
        @cache.find_peers({"length" => 500, "class" => "class1"}) =~ ["peer101"]
        @cache.preferentially_find_peers({"length" => 500, "class" => "class1"}) =~ ["peer101"]
      end

      it "should empty when require 5000 bytes." do
        @cache.find_peers({"length" => 5000}).should be_empty
      end
    end

    context "there are 6 peers, 5 writable and 1 readonly with various capacity" do
      before do
        @cache.set_status "peer100", ACTIVE,      100
        @cache.set_status "peer101", ACTIVE,     1000
        @cache.set_status "peer102", ACTIVE,    10000
        @cache.set_status "peer103", ACTIVE,   100000
        @cache.set_status "peer104", ACTIVE,  1000000
        @cache.set_status "peer105", READONLY,   1000
      end

      it "should return peers preferentially sorted by capacity." do
        rank = {"peer100" => 0, "peer101" => 0, "peer102" => 0, "peer103" => 0, "peer104" => 0, }
        100.times{
          rank[@cache.preferentially_find_peers({"length" => 50})[0]] += 1
        }
        rank = rank.sort { |x, y| y[1] <=> x[1] }.map{ |x| x[0] }
        rank.first.should == "peer104"
        rank.last.should  == "peer100"
        res =  @cache.preferentially_find_peers({"length" => 50})
        res =~ ["peer104", "peer103", "peer102", "peer101", "peer100"]
      end
    end

    after do
      @cache = nil
    end
  end

  private

  def same_elements? array1, array2
    array1.all? {|a| array2.include? a} and array2.all? {|a| array1.include? a}
  end

end
