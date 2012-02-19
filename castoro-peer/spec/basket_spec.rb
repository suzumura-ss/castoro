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

$:.unshift "#{File.dirname(__FILE__)}/../../castoro-common/lib"

require 'castoro-peer/basket'

describe Castoro::Peer::Basket do

  args = {
    "Dec40Seq" => "1-999, 2000, 3000-3999",
    "Hex64Seq" => "1000-1999",
  }
  base_dir = "/data"
  Castoro::Peer::Basket.setup args, base_dir
  count = 3

  before do
    time = mock(Time)
    time.stub!(:strftime).with("%Y%m%dT%H").and_return("20100812T11")
    time.stub!(:strftime).with("%Y%m%dT%H%M%S").and_return("20100812T112141")
    time.stub!(:usec).and_return(123456)
    Time.stub!(:new).and_return(time)
  end

  context "With an instance of #new( 987654321, 1, 2 )" do

    let(:basket) { Castoro::Peer::Basket.new 987654321, 1, 2 }

    describe "#content" do
      it "returns 987654321" do
        basket.content.should == 987654321
      end
    end

    describe "#type" do
      it "returns 1" do
        basket.type.should == 1
      end
    end

    describe "#revision" do
      it "returns 2" do
        basket.revision.should == 2
      end
    end

    describe "#to_s" do
      it 'returns "987654321.1.2"' do
        count.times do
          basket.to_s.should == "987654321.1.2"
        end
      end
    end

    describe "#path_w" do
      it 'returns "/data/1/baskets/w/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn"' do
        count.times do
          basket.path_w.should =~ %r"/data/1/baskets/w/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}"
        end
      end
    end

    describe "#path_r" do
      it 'returns "/data/1/baskets/r/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn"' do
        count.times do
          basket.path_r.should =~ %r"/data/1/baskets/r/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}"
        end
      end
    end

    describe "#path_a" do
      it 'returns "/data/1/baskets/a/0/987/654/987654321.1.2"' do
        count.times do
          basket.path_a.should =~ %r"/data/1/baskets/a/0/987/654/987654321\.1\.2"
        end
      end
    end

    describe "#path_d" do
      it 'returns "/data/1/baskets/d/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn"' do
        count.times do
          basket.path_d.should =~ %r"/data/1/baskets/d/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}"
        end
      end
    end

    describe "#path_c" do
      context "without calling #path_c_with_hint" do
        it 'returns "/data/1/offline/canceled/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn"' do
          count.times do
            basket.path_c.should =~ %r"/data/1/offline/canceled/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}"
          end
        end
      end
    end

  end

  context "With an instance of #new( 987654321, 1, 2 )" do

    basket = Castoro::Peer::Basket.new 987654321, 1, 2

    x = "/data/1/baskets/w/20100812T11/987654321.1.2.20100812T112141.123.810624"
    y = "/data/1/offline/canceled/20100812T11/987654321.1.2.20100812T112141.123.810624"

    describe "#path_c_with_hint" do
      context "with \"#{x}\"" do
        it "returns \"#{y}\"" do
          count.times do
            basket.path_c_with_hint(x).should == y
          end
        end
      end
    end

    describe "#path_c" do
      context "after calling #path_c_with_hint" do
        it "returns \"#{y}\"" do
          count.times do
            basket.path_c.should == y
          end
        end
      end
    end

  end

  context 'With an instance of #new_from_text( "987654321.1.2" )' do

    basket = Castoro::Peer::Basket.new_from_text "987654321.1.2"

    describe "#content" do
      it "returns 987654321" do
        basket.content.should == 987654321
      end
    end

    describe "#type" do
      it "returns 1" do
        basket.type.should == 1
      end
    end

    describe "#revision" do
      it "returns 2" do
        basket.revision.should == 2
      end
    end

  end
end
