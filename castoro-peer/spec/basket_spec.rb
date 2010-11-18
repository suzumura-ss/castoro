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

require 'castoro-peer/basket'

describe Castoro::Peer::Basket do
  before do
    Castoro::Peer::Basket.class_variable_set :@@base_dir, "/hoge"

    @times_of_directory_test = 100

    @time = mock(Time)
    @time.stub!(:strftime).with("%Y%m%dT%H").and_return("20100812T11")
    @time.stub!(:strftime).with("%Y%m%dT%H%M%S").and_return("20100812T112141")
    @time.stub!(:usec).and_return(123456)
    Time.stub!(:new).and_return(@time)
  end

  it "S_ABCENSE should 1" do
    Castoro::Peer::Basket::S_ABCENSE.should == 1
  end

  it "S_WORKING should 2" do
    Castoro::Peer::Basket::S_WORKING.should == 2
  end

  it "S_REPLICATING should 3" do
    Castoro::Peer::Basket::S_REPLICATING.should == 3
  end

  it "S_ARCHIVED should 4" do
    Castoro::Peer::Basket::S_ARCHIVED.should == 4
  end

  it "S_DELETED should 5" do
    Castoro::Peer::Basket::S_DELETED.should == 5
  end

  it "S_CONFLICT should 6" do
    Castoro::Peer::Basket::S_CONFLICT.should == 6
  end

  context "When 987654321 set to content_id, and 1 set to type_id and 2 set to revision_number." do
    it "The instance must be generable." do
      Castoro::Peer::Basket.new 987654321, 1, 2
    end

    context "When the instance is generable." do
      before do
        @b = Castoro::Peer::Basket.new 987654321, 1, 2
        class << @b; public :big_number; end
        @b.stub!(:big_number).and_return(2965386810624)
      end

      it "#content_id should 987654321" do
        @b.content_id.should == 987654321
      end

      it "#type_id should 1" do
        @b.type_id.should == 1
      end

      it "#revision_number should 2" do
        @b.revision_number.should == 2
      end

      it "#to_s should == '987654321.1.2'" do
        @times_of_directory_test.times {
          @b.to_s.should == "987654321.1.2"
        }
      end

      it "Working directory should == '/hoge/1/baskets/w/20100812T11/987654321.1.2.20100812T112141.123.810624'" do
        @times_of_directory_test.times {
          @b.path_w.should == "/hoge/1/baskets/w/20100812T11/987654321.1.2.20100812T112141.123.810624"
        }
      end

      it "Replication directory should == ''" do
        @times_of_directory_test.times {
          @b.path_r.should == "/hoge/1/baskets/r/20100812T11/987654321.1.2.20100812T112141.123.810624"
        }
      end

      it "Archived directory should == '/hoge/1/baskets/a/0/987/654/987654321.1.2'" do
        @times_of_directory_test.times {
          @b.path_a.should == "/hoge/1/baskets/a/0/987/654/987654321.1.2"
        }
      end

      it "Deleted directory should == '/hoge/1/baskets/d/20100812T11/987654321.1.2.20100812T112141.123.810624'" do
        @times_of_directory_test.times {
          @b.path_d.should == "/hoge/1/baskets/d/20100812T11/987654321.1.2.20100812T112141.123.810624"
        }
      end

      it "Canceled directory should == '/hoge/1/offline/canceled/20100812T11/987654321.1.2.20100812T112141.123.810624'" do
        @times_of_directory_test.times {
          @b.path_c.should == "/hoge/1/offline/canceled/20100812T11/987654321.1.2.20100812T112141.123.810624"
        }
      end
    end
  end

  context "When '987654321.1.2' set to constructor argument" do
    it "#new_from_text should succeed." do
      b = Castoro::Peer::Basket.new_from_text('987654321.1.2')
      b.content_id.should      == 987654321
      b.type_id.should         == 1
      b.revision_number.should == 2
    end
  end

  after do
    @config = nil
    @time   = nil
  end
end

