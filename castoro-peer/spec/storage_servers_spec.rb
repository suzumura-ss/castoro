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

HostnameForClient = "host5"
StorageHostsYamlPath = "/etc/castoro/storage_hosts.yml"
StorageHostsYaml = {"host1"=> "host1rep","host6"=> "host6rep",}
StorageGroupsJsonPath = "/etc/castoro/storage_groups.json.hoge"
StorageGroups = "[[\"host1\",\"host2\",\"host3\"],[\"host4\",\"host5\",\"host6\",\"host7\"],[\"host8\",\"host9\"]]"

describe Castoro::Peer::StorageServers do
  before do
    @servers = Castoro::Peer::StorageServers
    @config  = mock(Castoro::Peer::Configurations)
    @config.stub!(:HostnameForClient).and_return(HostnameForClient)
    @config.stub!(:StorageHostsYaml).and_return(StorageHostsYamlPath)
    @config.stub!(:StorageGroupsJson).and_return(StorageGroupsJsonPath)
    Castoro::Peer::Configurations.stub!(:instance).and_return(@config)
  end

  context "when initialize" do
    it "should not be able to use #new method." do
      Proc.new{
        Castoro::Peer::StorageServers.new
      }.should raise_error(NoMethodError)
    end

    it "should raise error if storage_hosts.yml does not exist." do
      Proc.new{
        @servers.instance
      }.should raise_error(Errno::ENOENT)
    end

    it "should raise error if storage_groups.json does not exist." do
      YAML.should_receive(:load_file).with(StorageHostsYamlPath).and_return(StorageHostsYaml)
      Proc.new{
        @servers.instance
      }.should raise_error(Errno::ENOENT)
    end

    it "should be able to #instance method to create unique instance." do
      YAML.should_receive(:load_file).with(StorageHostsYamlPath).and_return(StorageHostsYaml)
      IO.should_receive(:read).with(StorageGroupsJsonPath).and_return(StorageGroups)
      @servers.instance.should be_kind_of Castoro::Peer::StorageServers
    end

    it "should be set variables correctly." do
      @servers.instance.instance_variable_get(:@index).should == 0
    end

    it "should load hosts correctly." do
      @servers.instance.my_host.should == HostnameForClient
      @servers.instance.target.should == "host6rep"
      @servers.instance.alternative_hosts.should == ["host7","host4"]
      @servers.instance.colleague_hosts.should == ["host6rep","host7","host4"]
    end
  end

  after do
   @servers = nil
   @config = nil
  end
end
