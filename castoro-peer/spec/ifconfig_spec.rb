#
#   Cloneright 2010 Ricoh Company, Ltd.
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

require 'castoro-peer/ifconfig'

describe Castoro::Peer::IfConfig do
  before do
    Socket.stub!(:gethostname).and_return("foo.bar.baz")
    IPSocket.stub!(:getaddress).and_return("192.168.254.254")

    @dummy_proc = Proc.new {
                    [
                      "192.168.1.1",
                      "192.168.2.22",
                      "192.168.3.123",
                    ]
                  }
    @ifcfg = ::Castoro::Peer::IfConfig.new enum_if_proc: @dummy_proc                  
  end

  it "should specified ipaddress exist." do
    @ifcfg.multicast_interface_by_network_address("192.168.2.0/24").should == "192.168.2.22"
    @ifcfg.multicast_interface_by_network_address("192.168.1.0/24").should == "192.168.1.1"
    @ifcfg.multicast_interface_by_network_address("192.168.3.0/24").should == "192.168.3.123"
  end

  it "should satisfied ipaddress must not exist." do
    Proc.new {
      @ifcfg.multicast_interface_by_network_address("192.168.4.0/24")
    }.should raise_error(ArgumentError)
  end

  it "should two or more satisfied ipaddressmust exist." do
    Proc.new {
      @ifcfg.multicast_interface_by_network_address("192.168.2.0/23")
    }.should raise_error(ArgumentError)
  end
  
  describe "#has_interface?" do
    it "should '192.168.1.1' is exist." do
      @ifcfg.has_interface?("192.168.1.1").should == true
    end

    it "should '192.168.4.1' is exist." do
      @ifcfg.has_interface?("192.168.4.1").should == false
    end
  end

  describe "#default_hostname" do
    it "should equal 'foo.bar.baz'" do
      @ifcfg.default_hostname.should == "foo.bar.baz"
    end
  end

  describe "#default_interface_address" do
    it "should equal '192.168.254.254'" do
      @ifcfg.default_interface_address.should == "192.168.254.254"
    end
  end

  after do
    #
  end
end

