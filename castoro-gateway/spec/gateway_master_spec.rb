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

describe Castoro::Gateway do
  before do
    @logger = Logger.new nil
  end

  describe "given master configurations" do
    before do
      config = Castoro::Gateway::Configuration.new "type" => "master"
      @g = Castoro::Gateway.new config, @logger
    end
    
    it "repository should not receive .new" do
      Castoro::Gateway::Repository.should_not_receive(:new)
      @g.start
      sleep 0.5
    end

    it "facade should receive .new" do
      alive = false
      facade = mock(Castoro::Gateway::Facade)
      facade.stub!(:start).and_return { alive = true }
      facade.stub!(:stop).and_return { alive = false }
      facade.stub!(:alive?).and_return { alive }
      facade.stub!(:recv)
      Castoro::Gateway::Facade.should_receive(:new).and_return(facade)
      @g.start
      sleep 0.5
    end

    it "console server should not receive .new" do
      Castoro::Gateway::ConsoleServer.should_not_receive(:new)
      @g.start
      sleep 0.5
    end

    it "watchdog sender should not receive .new" do
      Castoro::Gateway::WatchdogSender.should_not_receive(:new)
      @g.start
      sleep 0.5
    end

    it "workers should not receive .new" do
      Castoro::Gateway::Workers.should_not_receive(:new)
      @g.start
      sleep 0.5
    end

    it "master_workers should receive .new" do
      alive = false
      workers = mock(Castoro::Gateway::MasterWorkers)
      workers.stub!(:start).and_return { alive = true }
      workers.stub!(:stop).and_return { alive = false }
      workers.stub!(:alive?).and_return { alive }
      Castoro::Gateway::MasterWorkers.should_receive(:new).and_return(workers)
      @g.start
      sleep 0.5
    end

    after do
      if @g
        @g.stop rescue nil
      end
      @g = nil
    end
  end
end

