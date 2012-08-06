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

describe Castoro::Gateway::ConsoleServer do
  before do
    # the Logger
    @logger = Logger.new(ENV['DEBUG'] ? STDOUT : nil)
    @port = ENV['CONSOLE_PORT'] ? ENV['CONSOLE_PORT'].to_i : 30110
    @ip = ENV['IP'] ? ENV['IP'] : "127.0.0.1"

    # mock for repository
    cached = [
      { :b => "1.2.3", :p => "peer1" },
      { :b => "1.2.3", :p => "peer2" },
      { :b => "1.2.3", :p => "peer3" },
      { :b => "2.3.4", :p => "peer1" },
      { :b => "2.3.4", :p => "peer2" },
      { :b => "2.3.4", :p => "peer3" },
    ]
    @r = mock Castoro::Gateway::Repository
    @r.stub!(:status).and_return {
      {
        "foo" => "FOO",
        "bar" => "BAR",
        "baz" => "BAZ",
      }
    }
    @r.stub!(:peersStatus).and_return {
      [ ["peer1", 10, 30], ["peer2", 20, 30], ["peer3", 30, 10]]
    }
    @r.stub!(:dump).and_return { |io, peers|
      cached.each { |c|
        io.puts "  #{c[:p]}: #{c[:b]}" if peers.nil? or peers.include?(c[:p])
      }
      io.puts
      true
    }
    @r.stub!(:drop).and_return { |b, p|
      cached.delete :b => b, :p => p
    }

    @c = Castoro::Gateway::ConsoleServer.new @logger, @r, @ip, @port
  end

  describe "#status" do
    it "repository should receive status" do
      @r.should_receive(:status).with(no_args)
      @c.status.should == {
        "foo" => "FOO",
        "bar" => "BAR",
        "baz" => "BAZ",
      }
    end
  end

  describe "#peersStatus" do
    it "repository should receive peerStatus" do
      @r.should_receive(:peersStatus).with(no_args)
      @c.peersStatus.should == [["peer1", 10, 30], ["peer2", 20, 30], ["peer3", 30, 10]]
    end
  end

  describe "#dump" do
    it "repository should receive dump" do
      io = StringIO.new
      @c.dump io
      io.string.should == <<EOF
  peer1: 1.2.3
  peer2: 1.2.3
  peer3: 1.2.3
  peer1: 2.3.4
  peer2: 2.3.4
  peer3: 2.3.4

EOF
    end
  end

  describe "#purge" do
    context "given args peer1 and peer2" do
      it "repository should receive drop" do
        @r.should_receive(:drop).with("1.2.3", "peer1").exactly(1)
        @r.should_receive(:drop).with("1.2.3", "peer3").exactly(1)
        @r.should_receive(:drop).with("2.3.4", "peer1").exactly(1)
        @r.should_receive(:drop).with("2.3.4", "peer3").exactly(1)
        @c.purge "peer1", "peer3"
      end

      it "cached data should remain peer2" do
        @c.purge "peer1", "peer3"

        io = StringIO.new
        @c.dump io
        io.string.should == <<EOF
  peer2: 1.2.3
  peer2: 2.3.4

EOF
      end
    end
  end

  context "when start" do
    before do
      @c.start
    end

    it "should alive" do
      @c.alive?.should == true
    end

    it "should listen drb access port" do
      begin
        DRb.start_service
        obj = DRbObject.new_with_uri "druby://#{@ip}:#{@port}"
      rescue
        DRb.stop_service
      end
    end

    it "should not be able to start" do
      Proc.new {
        @c.start
      }.should raise_error
    end

    context "when stop" do
      before do
        @c.stop
      end

      it "should not alive" do
        @c.alive?.should == false
      end

      it "should not be able to stop" do
        Proc.new {
          @c.stop
        }.should raise_error
      end
    end

    after do
      @c.stop if @c.alive?
    end
  end

  after do
    @c = nil
  end
end

