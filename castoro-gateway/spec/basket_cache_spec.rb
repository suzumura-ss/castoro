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
                       ['peer100', 'peer101']
                     else
                       []
                     end
        available_peers.select{ |peer|
          storeables.include?(peer)
        }
      }",
}


describe Castoro::BasketCache do
  context "when empty" do
    before do
      logger = Logger.new nil
      @cache = Castoro::BasketCache.new logger, CACHE_SETTINGS

      @cache.set_status "peer100", ACTIVE, available
    end

    it "should be empty" do
      @cache.find_by_key(keys[1]).should be_empty
    end

    after do
      @cache = nil
    end
  end

  context "when insert a item" do
    before do
      logger = Logger.new nil
      @cache = Castoro::BasketCache.new logger, CACHE_SETTINGS

      @cache.insert(keys[0], "peer100", "/expdsk/baskets")
      @cache.insert(keys[1], "peer101", "/expdsk/baskets")
      @cache.insert(keys[2], "peer102", "/expdsk/baskets")
    end

    it "should be empty when insert and remove it" do
      @cache.set_status "peer100", ACTIVE, available
      @cache.erase_by_peer_and_key("peer100", keys[0])
      @cache.erase_by_peer_and_key("peer101", keys[1])
      @cache.erase_by_peer_and_key("peer102", keys[2])
      @cache.find_by_key(keys[0]).should be_empty
      @cache.find_by_key(keys[1]).should be_empty
      @cache.find_by_key(keys[2]).should be_empty
    end

    it "should be empty when insert but NOT activated" do
      @cache.find_by_key(keys[0]).should be_empty
      @cache.find_by_key(keys[1]).should be_empty
      @cache.find_by_key(keys[2]).should be_empty
    end

    it "should be one item when mark active" do
      @cache.set_status "peer100", ACTIVE, available
      @cache.set_status "peer101", ACTIVE, available
      @cache.set_status "peer102", ACTIVE, available
      @cache.find_by_key(keys[0]).should == {
          "peer100" => "/expdsk/baskets/0/000/000/291.1.3",
      }
      @cache.find_by_key(keys[1]).should == {
          "peer101" => "/expdsk/baskets/0/004/567/4567890.1.2",
      }
      @cache.find_by_key(keys[2]).should == {
          "peer102" => "/expdsk/baskets/0/001/357/1357902.0.3",
      }
    end

    it "should be one item when mark readonly" do
      @cache.set_status "peer100", READONLY, available
      @cache.set_status "peer101", READONLY, available
      @cache.set_status "peer102", READONLY, available
      @cache.find_by_key(keys[0]).should == {
          "peer100" => "/expdsk/baskets/0/000/000/291.1.3",
      }
      @cache.find_by_key(keys[1]).should == {
          "peer101" => "/expdsk/baskets/0/004/567/4567890.1.2",
      }
      @cache.find_by_key(keys[2]).should == {
          "peer102" => "/expdsk/baskets/0/001/357/1357902.0.3",
      }
    end

    it "should be empty when mark maintenance" do
      @cache.set_status "peer100", MAINTENANCE, available
      @cache.set_status "peer101", MAINTENANCE, available
      @cache.set_status "peer102", MAINTENANCE, available
      @cache.find_by_key(keys[0]).should be_empty
      @cache.find_by_key(keys[1]).should be_empty
      @cache.find_by_key(keys[2]).should be_empty
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
    end

    context "there is 3 peers, there are 100 and 1000 bytes writable class1 and 1000 bytes writable class2" do
      before do
        @cache.set_status "peer100", ACTIVE, 100
        @cache.set_status "peer101", ACTIVE, 1000
        @cache.set_status "peer102", ACTIVE, 1000
      end

      it "should be used default class and included 2 peers when require 50 bytes and without class" do
        same_elements?(@cache.find_peers({"length" => 50}), ["peer100","peer101"]).should be_true
      end

      it "should be included 2 peers when require 50 bytes and class = class1" do
        same_elements?(@cache.find_peers({"length" => 50, "class" => "class1"}), ["peer100","peer101"]).should be_true
      end

      it "should be included 1 peer when require class = class2" do
        same_elements?(@cache.find_peers({"class" => "class2"}), ["peer102"])
      end

      it "should be included 1 peers when require 500 bytes and class = class1" do
        same_elements?(@cache.find_peers({"length" => 500, "class" => "class1"}), ["peer101"]).should be_true
      end

      it "should empty when require 5000 bytes" do
        @cache.find_peers({"length" => 5000}).should be_empty
      end
    end

    context "there is 4 peers, there are 100 bytes writable and 1000 bytes avail but readonly each class1 and class2" do
      before do
        @cache.set_status "peer100", ACTIVE  , 100
        @cache.set_status "peer101", READONLY, 1000
        @cache.set_status "peer102", ACTIVE  , 100
        @cache.set_status "peer103", READONLY, 1000
      end

      it "should be used default class and included 1 peer when require 50 bytes and without class" do
        same_elements?(@cache.find_peers({"length" => 50}), ["peer100"]).should be_true
      end

      it "should be included 1 peer when require 50 bytes and class = class2" do
        same_elements?(@cache.find_peers({"length" => 50, "class" => "class2"}), ["peer102"]).should be_true
      end

      it "should be empty when require 50 bytes and class = class3" do
        @cache.find_peers({"length" => 50, "class" => "class3"}).should be_empty
      end

      it "should empty when require 500 bytes" do
        @cache.find_peers({"length" => 500}).should be_empty
      end

      it "should empty when require 5000 bytes" do
        @cache.find_peers({"length" => 5000}).should be_empty
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

