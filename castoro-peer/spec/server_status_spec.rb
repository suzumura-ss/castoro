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

require "castoro-peer/server_status"

describe Castoro::Peer::ServerStatus do
  before do
    @s_stat = Castoro::Peer::ServerStatus
  end

  context "when initialize" do
    it "should not be able to use #new method." do
      Proc.new{
        Castoro::Peer::ServerStatus.new
      }.should raise_error(NoMethodError)
    end

    it "should be able to #instance method to create unique instance." do
      @s_stat.instance.should be_kind_of Castoro::Peer::ServerStatus
    end

    it "should be set variables correctly." do
      @s_stat.instance.status.should == Castoro::Peer::ServerStatus::OFFLINE
      @s_stat.instance.instance_variable_get(:@mutex).should be_kind_of Mutex
    end
  end

  context "when #status=" do
    it '(30) @status should be changed to "30 online" from "10 offline"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s("10")} to #{@s_stat.status_to_s("30")}").
        exactly(1)
      @s_stat.instance.status= 30 
      @s_stat.instance.status.should == 30
      @s_stat.instance.status_name.should == "30 online"
    end

    it '("20") @status should be changed to "20 readonly" from "30 online"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s(30)} to #{@s_stat.status_to_s("20")}").
        exactly(1)
      @s_stat.instance.status= "20"
      @s_stat.instance.status.should == "20"
      @s_stat.instance.status_name.should == "20 readonly"
    end

    it '(20) @status should be changed to "20 readonly" from "20 readonly"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s("20")} to #{@s_stat.status_to_s("20")}").
        exactly(1)
      @s_stat.instance.status= 20
      @s_stat.instance.status.should == 20
      @s_stat.instance.status_name.should == "20 readonly"
    end

    it '("hoge") @status should be changed to "? ?" from "20 readonly"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s(20)} to #{@s_stat.status_to_s("hoge")}").
        exactly(1)
      @s_stat.instance.status= "hoge"
      @s_stat.instance.status.should == "hoge"
      @s_stat.instance.status_name.should == "? ?"
    end
  end

  context "when #status_name=" do
    it '("offline") @status should be changed to "10 offline" from "? ?"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s("hoge")} to #{@s_stat.status_to_s(10)}").
        exactly(1)
      @s_stat.instance.status_name= "offline" 
      @s_stat.instance.status.should == 10
      @s_stat.instance.status_name.should == "10 offline"
    end

    it '("rep") @status should be changed to "23 rep" from "hoge"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s(10)} to #{@s_stat.status_to_s(23)}").
        exactly(1)
      @s_stat.instance.status_name= "rep"
      @s_stat.instance.status.should == 23
      @s_stat.instance.status_name.should == "23 rep"
    end

    it '("0") @status should be changed to "0 unknown" from "23 rep"' do
      Castoro::Peer::Log.should_receive(:notice).
        with("STATUS changed from #{@s_stat.status_to_s(23)} to #{@s_stat.status_to_s(0)}").
        exactly(1)
      @s_stat.instance.status_name= "0"
      @s_stat.instance.status.should == 0
      @s_stat.instance.status_name.should == "0 unknown"
    end        
  end

  context "when #status_to_s" do
    `it 'with "ONLINE" should return "30 online"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::ONLINE).should == "30 online"
    end

    it 'with "30" should return "30 online"' do
      @s_stat.status_to_s("30").should == "30 online"
    end

    it 'with "DEL_REP" should return "27 del_rep"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::DEL_REP).should == "27 del_rep"
    end

    it 'with "27" should return "27 del_rep"' do
      @s_stat.status_to_s("27").should == "27 del_rep"
    end

    it 'with "FIN_REP" should return "25 fin_rep"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::FIN_REP).should == "25 fin_rep"
    end

    it 'with "25" should return "25 fin_rep"' do
      @s_stat.status_to_s("25").should == "25 fin_rep"
    end

    it 'with "REP" should return "23 rep"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::REP).should == "23 rep"
    end

    it 'with "23" should return "23 rep"' do
      @s_stat.status_to_s("23").should == "23 rep"
    end

    it 'with "READONLY" should return "20 readonly"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::READONLY).should == "20 readonly"
    end

    it 'with "20" should return "20 readonly"' do
      @s_stat.status_to_s("20").should == "20 readonly"
    end

    it 'with "OFFLINE" should return "10 offline"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::OFFLINE).should == "10 offline"
    end

    it 'with "10" should return "10 offline"' do
      @s_stat.status_to_s("10").should == "10 offline"
    end

    it 'with "UNKNOWN" should return "0 unknown"' do
      @s_stat.status_to_s(Castoro::Peer::ServerStatus::UNKNOWN).should == "0 unknown"
    end

    it 'with "0" should return "0 unknown"' do
      @s_stat.status_to_s("0").should == "0 unknown"
    end

    it 'with "-10"' do
      @s_stat.status_to_s("-10").should == "? ?"
    end
  end

  context "when #status_name_to_i" do
    it "with 'online' should return 30" do
      @s_stat.status_name_to_i("online").should == 30
    end

    it "with '30' should return 30" do
      @s_stat.status_name_to_i("online").should == 30
    end

    it "with 'del_rep' should return 27" do
      @s_stat.status_name_to_i("del_rep").should == 27
    end

    it "with '27' should return 27" do
      @s_stat.status_name_to_i("27").should == 27
    end

    it "with 'fin_rep' should return 25" do
      @s_stat.status_name_to_i("fin_rep").should == 25
    end

    it "with '25' should return 25" do
      @s_stat.status_name_to_i("25").should == 25
    end

    it "with 'rep' should return 23" do
      @s_stat.status_name_to_i("rep").should == 23
    end

    it "with '23' should return 23" do
      @s_stat.status_name_to_i("23").should == 23
    end

    it "with 'readonly' should return 20" do
      @s_stat.status_name_to_i("readonly").should == 20
    end

    it "with '20' should return 20" do
      @s_stat.status_name_to_i("20").should == 20
    end

    it "with 'offline' should return 10" do
      @s_stat.status_name_to_i("offline").should == 10
    end

    it "with '10' should return 10" do
      @s_stat.status_name_to_i("10").should == 10
    end

    it "with 'unknown' should return 0" do
      @s_stat.status_name_to_i("unknown").should == 0
    end

    it "with '0' should return 0" do
      @s_stat.status_name_to_i("0").should == 0
    end

    it "with 'nothing' should raise StandardError" do
      Proc.new{
        @s_stat.status_name_to_i("nothing")
      }.should raise_error(StandardError)
    end

    it "with '-10' should raise StandardError" do
      Proc.new{
        @s_stat.status_name_to_i("-10")
      }.should raise_error(StandardError)
    end
  end

  after do
    @s_stat = nil
  end
end

