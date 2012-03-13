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

require 'stringio'

describe Castoro::Cache::KyotoCabinet do
  describe "#initialize" do
    context "given negative number to size" do
      it "should raise ArgumentError" do
        Proc.new {
          Castoro::Cache::KyotoCabinet.new -1
        }.should raise_error(ArgumentError)
      end
    end

    context "given negative number to options[:watchdog_limit]" do
      it "should raise ArgumentError" do
        Proc.new {
          Castoro::Cache::KyotoCabinet.new 1024*1024*1024, :watchdog_limit => -1
        }.should raise_error(ArgumentError)
      end
    end
  end

  describe "instance." do
    before do
      @c = Castoro::Cache::KyotoCabinet.new 1024*1024*1024, :watchdog_limit => 2
    end

    context "insert [p1,p2,p3] * [1.2.3, 4.5.6, 7.8.9]" do
      before do
        @c.insert_element "p1", 1, 2, 3
        @c.insert_element "p2", 1, 2, 3
        @c.insert_element "p3", 1, 2, 3
        @c.insert_element "p1", 4, 5, 6 
        @c.insert_element "p2", 4, 5, 6 
        @c.insert_element "p3", 4, 5, 6 
        @c.insert_element "p1", 7, 8, 9 
        @c.insert_element "p2", 7, 8, 9 
        @c.insert_element "p3", 7, 8, 9 
      end

      context "given status p1={30}, p2={20}, p3={10}" do
        before do
          @c.set_peer_status "p1", :status => 30
          @c.set_peer_status "p2", :status => 20
          @c.set_peer_status "p3", :status => 10
        end

        it "#find(1,2,3) should return [p1,p2]" do
          @c.find(1,2,3).should == ["p1", "p2"]
        end

        it "#find(4,5,6) should return [p1,p2]" do
          @c.find(4,5,6).should == ["p1", "p2"]
        end

        it "#find(7,8,9) should return [p1,p2]" do
          @c.find(7,8,9).should == ["p1", "p2"]
        end

        it "#find(9,9,9) should return []" do
          @c.find(9,9,9).should == []
        end

        context "erase p1>1.2.3, p2>4.5.6, p3>7.8.9" do
          before do
            @c.erase_element "p1", 1, 2, 3
            @c.erase_element "p2", 4, 5, 6
            @c.erase_element "p3", 7, 8, 9
          end

          it "#find(1,2,3) should return [p2]" do
            @c.find(1,2,3).should == ["p2"]
          end

          it "#find(4,5,6) should return [p1]" do
            @c.find(4,5,6).should == ["p1"]
          end

          it "#find(7,8,9) should return [p1,p2]" do
            @c.find(7,8,9).should == ["p1", "p2"]
          end

          it "#find(9,9,9) should return []" do
            @c.find(9,9,9).should == []
          end

          context "sleep 3" do
            before do
              sleep 3
            end

            it "#find(1,2,3) should return []" do
              @c.find(1,2,3).should == []
            end

            it "#find(4,5,6) should return []" do
              @c.find(4,5,6).should == []
            end

            it "#find(7,8,9) should return []" do
              @c.find(7,8,9).should == []
            end

            it "#find(9,9,9) should return []" do
              @c.find(9,9,9).should == []
            end
          end
        end
      end
    end

    describe "The same content, of the same type to save only one basket" do
      context "given insert p1>1.1.1, and p1 is active" do
        before do
          @c.insert_element "p1", 1, 1, 1
          @c.set_peer_status "p1", :status => 30
        end

        context "given insert p1>1.1.2" do
          before do
            @c.insert_element "p1", 1, 1, 2
          end

          it "should not found 1.1.1" do
            @c.find(1,1,1).should == []
          end

          it "should found 1.1.2" do
            @c.find(1,1,2).should == ["p1"]
          end
        end
      end
    end

    describe "peer capacity" do
      context "given status p1={30,123},p2={30,50},p3={20,123}" do
        before do
          @c.set_peer_status "p1", :status => 30, :available => 123
          @c.set_peer_status "p2", :status => 30, :available => 50
          @c.set_peer_status "p3", :status => 20, :available => 123
        end

        it "#find_peers(80) should return [p1]" do
          @c.find_peers(80).should == ["p1"]
        end

        it "#find_peers(40) should return [p1,p2]" do
          @c.find_peers(40).should == ["p1","p2"]
        end

        it "#find_peers(1000) should return []" do
          @c.find_peers(1000).should == []
        end

        it "#find_peers() should return [p1,p2,p3]" do
          @c.find_peers.should == ["p1","p2","p3"]
        end

        context "sleep 3" do
          before do
            sleep 3
          end

          it "#find_peers(80) should return []" do
            @c.find_peers(80).should == []
          end

          it "#find_peers(40) should return []" do
            @c.find_peers(40).should == []
          end

          it "#find_peers(1000) should return []" do
            @c.find_peers(1000).should == []
          end

          it "#find_peers() should return [p1,p2,p3]" do
            @c.find_peers.should == ["p1","p2","p3"]
          end
        end
      end
    end

    describe "#dump" do
      context "has nothing data" do
        it "#dump(io) should puts '\\n'" do
          io = StringIO.new
          @c.dump io
          io.string.should == "\n"
        end
      end

      context "insert p1->1.2.3" do
        before do
          @c.insert_element "p1", 1, 2, 3
        end

        it "#dump(io) should puts '  p1: 1.2.3\\n\\n'" do
          io = StringIO.new
          @c.dump io
          io.string.should == "  p1: 1.2.3\n\n"
        end
      end

      context "insert [p1,p2,p3] * [1.2.3, 4.5.6, 7.8.9]" do
        before do
          @c.insert_element "p1", 1, 2, 3
          @c.insert_element "p2", 1, 2, 3
          @c.insert_element "p3", 1, 2, 3
          @c.insert_element "p1", 4, 5, 6 
          @c.insert_element "p2", 4, 5, 6 
          @c.insert_element "p3", 4, 5, 6 
          @c.insert_element "p1", 7, 8, 9 
          @c.insert_element "p2", 7, 8, 9 
          @c.insert_element "p3", 7, 8, 9 
        end

        it "#dump(io) should puts all data" do
          io = StringIO.new
          @c.dump io
          io.string.split(/\n/).sort.should == [
            "  p1: 1.2.3", "  p1: 4.5.6", "  p1: 7.8.9",
            "  p2: 1.2.3", "  p2: 4.5.6", "  p2: 7.8.9",
            "  p3: 1.2.3", "  p3: 4.5.6", "  p3: 7.8.9",
          ]
        end

        it "#dump(io, 'p1') should puts p1 filtered data" do
          io = StringIO.new
          @c.dump io, "p1"
          io.string.split(/\n/).sort.should == [
            "  p1: 1.2.3", "  p1: 4.5.6", "  p1: 7.8.9",
          ]
        end

        it "#dump(io, ['p1', 'p3']) should puts p1 filtered data" do
          io = StringIO.new
          @c.dump io, ["p1", "p3"]
          io.string.split(/\n/).sort.should == [
            "  p1: 1.2.3", "  p1: 4.5.6", "  p1: 7.8.9",
            "  p3: 1.2.3", "  p3: 4.5.6", "  p3: 7.8.9",
          ]
        end

        context "erase p1>1.2.3, p2>4.5.6, p3>7.8.9" do
          before do
            @c.erase_element "p1", 1, 2, 3
            @c.erase_element "p2", 4, 5, 6
            @c.erase_element "p3", 7, 8, 9
          end

          it "#dump(io) should puts all data" do
            io = StringIO.new
            @c.dump io
            io.string.split(/\n/).sort.should == [
              "  p1: 4.5.6", "  p1: 7.8.9",
              "  p2: 1.2.3", "  p2: 7.8.9",
              "  p3: 1.2.3", "  p3: 4.5.6",
            ]
          end

          it "#dump(io, 'p1') should puts p1 filtered data" do
            io = StringIO.new
            @c.dump io, "p1"
            io.string.split(/\n/).sort.should == [
              "  p1: 4.5.6", "  p1: 7.8.9",
            ]
          end

          it "#dump(io, ['p1', 'p3']) should puts p1 filtered data" do
            io = StringIO.new
            @c.dump io, ["p1", "p3"]
            io.string.split(/\n/).sort.should == [
              "  p1: 4.5.6", "  p1: 7.8.9",
              "  p3: 1.2.3", "  p3: 4.5.6",
            ]
          end
        end
      end
    end

    describe "#status" do
      describe "DSTAT_CACHE_*" do

        it "#stat(DSTAT_CACHE_EXPIRE) should == 2" do
          @c.stat(Castoro::Cache::DSTAT_CACHE_EXPIRE).should == 2
        end

        context "insert [p1,p2,p3] * [1.2.3, 4.5.6, 7.8.9], and all active" do
          before do
            @c.insert_element "p1", 1, 2, 3
            @c.insert_element "p2", 1, 2, 3
            @c.insert_element "p3", 1, 2, 3
            @c.insert_element "p1", 4, 5, 6
            @c.insert_element "p2", 4, 5, 6
            @c.insert_element "p3", 4, 5, 6
            @c.insert_element "p1", 7, 8, 9
            @c.insert_element "p2", 7, 8, 9
            @c.insert_element "p3", 7, 8, 9
            @c.set_peer_status "p1", :status => 30
            @c.set_peer_status "p2", :status => 30
            @c.set_peer_status "p3", :status => 30
          end

          context "#find(1,2,3) 70 times, #find(9,9,9) 30 times" do
            before do
              60.times { @c.find 1, 2, 3 }
              30.times { @c.find 9, 9, 9 }
            end

            it "#stat(DSTAT_CACHE_REQUESTS) should == 90" do
              @c.stat(Castoro::Cache::DSTAT_CACHE_REQUESTS).should == 90
            end

            it "#stat(DSTAT_CACHE_HITS) should == 60" do
              @c.stat(Castoro::Cache::DSTAT_CACHE_HITS).should == 60
            end

            it "#stat(DSTAT_CACHE_COUNT_CLEAR) should == (HITS*1000/REQUESTS)" do
              @c.stat(Castoro::Cache::DSTAT_CACHE_COUNT_CLEAR).should == 666
            end

            describe "after COUNT_CLEAR" do
              before do
                @c.stat(Castoro::Cache::DSTAT_CACHE_COUNT_CLEAR)
              end

              it "#stat(DSTAT_CACHE_REQUESTS) should == 0" do
                @c.stat(Castoro::Cache::DSTAT_CACHE_REQUESTS).should == 0
              end

              it "#stat(DSTAT_CACHE_HITS) should == 0" do
                @c.stat(Castoro::Cache::DSTAT_CACHE_HITS).should == 0
              end
            end
          end
        end
      end

      describe "DSTAT_ALLOCATE_PAGES" do
        it "should return 0" do
          @c.stat(Castoro::Cache::DSTAT_ALLOCATE_PAGES).should == 0
        end
      end

      describe "DSTAT_ACTIVE_PAGES" do
        it "should return 0" do
          @c.stat(Castoro::Cache::DSTAT_ACTIVE_PAGES).should == 0
        end
      end

      describe "DSTAT_FREE_PAGES" do
        it "should return 0" do
          @c.stat(Castoro::Cache::DSTAT_FREE_PAGES).should == 0
        end
      end

      describe "DSTAT_*_PEERS" do
        context "given p1>30, p2>20, p3>10" do
          before do
            @c.set_peer_status "p1", :status => 30
            @c.set_peer_status "p2", :status => 20
            @c.set_peer_status "p3", :status => 10
          end

          it "#stat(DSTAT_HAVE_STATUS_PEERS) should == 3" do
            @c.stat(Castoro::Cache::DSTAT_HAVE_STATUS_PEERS).should == 3
          end

          it "#stat(DSTAT_ACTIVE_PEERS) should == 1" do
            @c.stat(Castoro::Cache::DSTAT_ACTIVE_PEERS).should == 1
          end

          it "#stat(DSTAT_READABLE_PEERS) should == 2" do
            @c.stat(Castoro::Cache::DSTAT_READABLE_PEERS).should == 2
          end
        end
      end
    end

    after do
      @c = nil
    end
  end
end

