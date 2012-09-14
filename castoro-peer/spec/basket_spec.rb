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
    time.stub!(:strftime).with("%Y/%Y%m%dT%H").and_return("2010/20100812T11")
    time.stub!(:strftime).with("%Y%m%dT%H%M%S").and_return("20100812T112141")
    time.stub!(:usec).and_return(123456)
    Time.stub!(:new).and_return(time)
  end

  ######################################################################
  samples = [
             {
               :input => [ 987654321, 1, 2 ],
               :output => [
                           [ :to_s,
                             "987654321.1.2",
                             %r"\A987654321.1.2\Z", ],

                           [ :path_w,
                             "/data/1/baskets/w/2010/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn",
                             %r"\A/data/1/baskets/w/2010/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}\Z" ],

                           [ :path_r,
                             "/data/1/baskets/r/2010/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn",
                             %r"\A/data/1/baskets/r/2010/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}\Z" ],

                           [ :path_a,
                             "/data/1/baskets/a/0/987/654/987654321.1.2",
                             %r"\A/data/1/baskets/a/0/987/654/987654321\.1\.2\Z" ],

                           [ :path_d,
                             "/data/1/baskets/d/2010/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn",
                             %r"\A/data/1/baskets/d/2010/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}\Z" ],

                           [ :path_c,
                             "/data/1/offline/canceled/2010/20100812T11/987654321.1.2.20100812T112141.123.nnnnnn",
                             %r"\A/data/1/offline/canceled/2010/20100812T11/987654321\.1\.2\.20100812T112141\.123\.\d{6}\Z" ],
                          ],
             },

             {
               :input => [ "0x00fedcba98765432".hex, 1234, 5 ],
               :output => [
                           [ :to_s,
                             "0x00fedcba98765432.1234.5",
                             %r"\A0x00fedcba98765432\.1234\.5\Z", ],

                           [ :path_w,
                             "/data/1234/baskets/w/2010/20100812T11/00fedcba98765432.1234.5.20100812T112141.123.nnnnnn",
                             %r"\A/data/1234/baskets/w/2010/20100812T11/00fedcba98765432\.1234\.5\.20100812T112141\.123\.\d{6}\Z" ],

                           [ :path_r,
                             "/data/1234/baskets/r/2010/20100812T11/00fedcba98765432.1234.5.20100812T112141.123.nnnnnn",
                             %r"\A/data/1234/baskets/r/2010/20100812T11/00fedcba98765432\.1234\.5\.20100812T112141\.123\.\d{6}\Z" ],


                           [ :path_a,
                             "/data/1234/baskets/a/0/0fe/dcb/a98/765/00fedcba98765432.1234.5",
                             %r"\A/data/1234/baskets/a/0/0fe/dcb/a98/765/00fedcba98765432\.1234\.5\Z", ],

                           [ :path_d,
                             "/data/1234/baskets/d/2010/20100812T11/00fedcba98765432.1234.5.20100812T112141.123.nnnnnn",
                             %r"\A/data/1234/baskets/d/2010/20100812T11/00fedcba98765432\.1234\.5\.20100812T112141\.123\.\d{6}\Z" ],

                           [ :path_c,
                             "/data/1234/offline/canceled/2010/20100812T11/00fedcba98765432.1234.5.20100812T112141.123.nnnnnn",
                             %r"\A/data/1234/offline/canceled/2010/20100812T11/00fedcba98765432\.1234\.5\.20100812T112141\.123\.\d{6}\Z" ],
                          ],
             },
           ]

  samples.each do |sample|
    content, type, revision = sample[ :input ]
    context "With an instance of #new( #{content}, #{type}, #{revision} )" do
      basket = Castoro::Peer::Basket.new content, type, revision
      sample[ :output ].each do |x|
        method, output, pattern = x
        describe "##{method}" do
          it "returns \"#{output}\"" do
            count.times do
              basket.send( method ).should =~ pattern
            end
          end
        end
      end
    end
  end

  ######################################################################
  context "With an instance of #new( 987654321, 1, 2 )" do

    basket = Castoro::Peer::Basket.new 987654321, 1, 2

    x = "/data/1/baskets/w/2010/20100812T11/987654321.1.2.20100812T112141.123.810624"
    y = "/data/1/offline/canceled/2010/20100812T11/987654321.1.2.20100812T112141.123.810624"

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

  ######################################################################
  samples = [
             {
               :input => "987654321.1.2",
               :output => [ 987654321, 1, 2 ],
             },

             {
               :input => "0x00fedcba98765432.1234.5",
               :output => [ "0x00fedcba98765432".hex, 1234, 5 ],
             },
            ]

  samples.each do |sample|
    input = sample[ :input ]
    context "With an instance of #new_from_text( \"#{input}\" )" do
      basket = Castoro::Peer::Basket.new_from_text input
      content, type, revision = sample[ :output ]

      describe "#content" do
        it "returns #{content}" do
          basket.content.should == content
        end
      end

      describe "#type" do
        it "returns #{type}" do
          basket.type.should == type
        end
      end

      describe "#revision" do
        it "returns #{revision}" do
          basket.revision.should == revision
        end
      end

      describe "#to_s" do
        it "returns #{input}" do
          basket.to_s.should == input
        end
      end
    end
  end

end
