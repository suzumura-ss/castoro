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

require "castoro-peer/storage_servers"

# These configures are written in spec_helper.rb.
#
# When Castoro::Peer::Configurations::type == 0 (default)
#
# hostname_for_client = "host5"
# StorageHostsYaml  = {"host1"=> "host1rep","host6"=> "host6rep",}
# StorageGroups     = [["host1","host2","host3"],["host4","host5","host6","host7"],["host8","host9"]]
#
# When Castoro::Peer::Configurations::type == 1 (invalid configuration)
#
# hostname_for_client = "host"
# StorageHostsYaml  = {"host1"=> "host1rep","host6"=> "host6rep",}
# StorageGroups     = [["host1","host2","host3"],["host4","host5","host6","host7"],["host8","host9"]]

describe Castoro::Peer::StorageServers do
  before do
    @servers = Castoro::Peer::StorageServers
    Castoro::Peer::Configurations::type = 0
  end

  context "when initialize" do
    it "should not be able to use #new method." do
      Proc.new{
        Castoro::Peer::StorageServers.new
      }.should raise_error(NoMethodError)
    end

    it "should be able to #instance method to create unique instance." do
      @servers.instance.should be_kind_of Castoro::Peer::StorageServers
    end

    it "should load hosts correctly." do
      @servers.instance.target.should == "host6rep"
      @servers.instance.alternative_hosts.should == ["host7","host4"]
      @servers.instance.colleague_hosts.should == ["host6rep","host7","host4"]
    end

    context "but if hostname_for_client is not included in StorageGroups" do
      before do
        Castoro::Peer::Configurations::type = 1
      end

      it "should raise error." do
        pending "this case should be checked and rescued."
        Proc.new{
          @servers.instance.load
        }.should raise_error(BadRequestError)
      end

      after do
        Castoro::Peer::Configurations::type = 0
      end
    end
  end

  after do
    @servers = nil
  end
end
