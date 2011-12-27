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
  end

  context "given default argument" do
    before(:all) do
      @sender = Castoro::Gateway::WatchdogSender.new @logger
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

    after(:all) do
      @sender.stop if @sender and @sender.alive?
    end
  end
end

