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

describe Castoro::IslandId do
  context "given string 'e1234567'" do
    before(:all) do
      @island = Castoro::IslandId.new 'e1234567'
    end

    it "#to_s is 'e1234567'" do
      @island.to_s.should == 'e1234567'
    end

    it "#to_ip is '225.35.69.103'" do
      @island.to_ip.should == '225.35.69.103'
    end

    it "#to_island is self" do
      @island.to_island.should be_equal @island
    end

    it "same other instance" do
      @island.should == Castoro::IslandId.new('e1234567')
    end
  end

  context "given string 'eabcdef9'" do
    before(:all) do
      @island = Castoro::IslandId.new 'eabcdef9'
    end

    it "#to_s is 'eabcdef9'" do
      @island.to_s.should == 'eabcdef9'
    end

    it "#to_ip is '234.188.222.249'" do
      @island.to_ip.should == '234.188.222.249'
    end

    it "#to_island is self" do
      @island.to_island.should be_equal @island
    end

    it "same other instance" do
      @island.should == Castoro::IslandId.new('eabcdef9')
    end
  end

  describe "givn ip address" do
    context "given ip address '239.168.0.1'" do
      before(:all) do
        @island = Castoro::IslandId.new '239.168.0.1'
      end

      it "#to_s is 'efa80001'" do
        @island.to_s.should == 'efa80001'
      end

      it "#to_ip is '239.168.0.1'" do
        @island.to_ip.should == '239.168.0.1'
      end

      it "#to_island is self" do
        @island.to_island.should be_equal @island
      end

      it "same other instance" do
        @island.should == Castoro::IslandId.new('efa80001')
      end
    end

    context "given not multicast address" do
      it "should raise error" do
        Proc.new {
          Castoro::IslandId.new '192.168.0.1'
        }.should raise_error(Castoro::IslandIdError)
      end
    end
  end

  context "given 8 length letters" do
    it "should raise error" do
      Proc.new {
        Castoro::IslandId.new 'c0a80001'
      }.should raise_error(Castoro::IslandIdError)
    end
  end

  context "given nil" do
    it "should raise error" do
      Proc.new {
        Castoro::IslandId.new nil
      }.should raise_error(Castoro::IslandIdError)
    end
  end

  context "given fixnum" do
    it "should raise error" do
      Proc.new {
        Castoro::IslandId.new 123456
      }.should raise_error(Castoro::IslandIdError)
    end
  end

  describe "helper" do
    describe "String class" do
      it "convertable by #to_island" do
        "eb12de34".to_island.should be_kind_of Castoro::IslandId
      end
    end
  end
end

