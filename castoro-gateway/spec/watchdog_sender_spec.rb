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

describe Castoro::Gateway::WatchdogSender do
  before(:all) do
    @logger = Logger.new nil
    @repository = Object.new
    class << @repository
      def storables
        15
      end
      def capacity
        123456789
      end
    end
    @island = "ab12cd34".to_island
  end

  context "given default argument" do
    before(:all) do
      @sender = Castoro::Gateway::WatchdogSender.new @logger, @repository, @island
    end

    it "should not alive" do
      @sender.alive?.should == false
    end

    context "when start" do
      before(:all) do
        @sender.start
      end

      it "should alive" do
        @sender.alive?.should == true
      end

      context "when stop" do
        before(:all) do
          @sender.stop
        end

        it "should not alive" do
          @sender.alive?.should == false
        end
      end
    end

    describe "multicast expectation" do
      before do
        @multicast = mock(Castoro::Sender::UDP::Multicast)
        Castoro::Sender::UDP::Multicast.stub!(:new).and_yield(@multicast)
        @random = mock(Random)
        @random.stub!(:rand).with(60..300).and_return(1)
        Random.stub!(:new).and_return(@random)

        @sender = Castoro::Gateway::WatchdogSender.new @logger, @repository, @island, :if_addr => '127.0.0.1'
      end

      it "should send multicast at regular intervals." do
        header = Castoro::Protocol::UDPHeader.new('127.0.0.1', 0)
        command = Castoro::Protocol::Command::Island.new @island, 15, 123456789
        @multicast.should_receive(:multicast).with(header, command).exactly(3)
        @sender.start
        sleep 2.5
      end
    end

    after(:all) do
      @sender.stop if @sender and @sender.alive?
    end
  end
end

