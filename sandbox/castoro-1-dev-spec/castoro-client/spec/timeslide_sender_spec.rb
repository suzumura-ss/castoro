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

describe Castoro::Client::TimeslideSender do
  Spec::Matchers.define :included do |expected|
    match do |actual|
      expected.include? actual
    end
  end

  before(:all) do
    # times.
    @times_of_start_and_stop = 1000
    @times_of_send           = 10000

    # configurations
    @logger = Logger.new(nil)
    @my_host  = "127.0.0.1"
    @my_ports = [
      30003,
      30004,
      30005,
    ]
    @destinations = [
      "127.0.0.1:30006",
      "127.0.0.1:30007",
      "127.0.0.1:30008",
    ]
    @expire = 2.0
    @request_interval = 0.20

    @gateway_mock = {}
    # mock - 30006
    @gateway_mock[30006] = Castoro::Receiver::UDP.new(@logger, 30006) { |h, d, p, i|
      Castoro::Sender::UDP.start(@logger) { |r|
        c = Castoro::Protocol::Response::Nop.new(nil)
        r.send h, c, h.ip, h.port
      }
    }
    # mock - 30007
    @gateway_mock[30007] = Castoro::Receiver::UDP.new(@logger, 30007) { |h, d, p, i|
      Castoro::Sender::UDP.start(@logger) { |r|
        c = Castoro::Protocol::Response::Nop.new(nil)
        r.send h, c, h.ip, h.port
      }
    }
    # mock - 30008
    @gateway_mock[30008] = Castoro::Receiver::UDP.new(@logger, 30008) { |h, d, p, i|
      Castoro::Sender::UDP.start(@logger) { |r|
        c = Castoro::Protocol::Response::Nop.new(nil)
        r.send h, c, h.ip, h.port
      }
    }
    @gateway_mock.each { |port, mock| mock.start }
  end

  context "when port number 30003 is blocked" do
    before do
      @blockers = []
      @blockers << Castoro::Receiver::UDP.new(@logger, 30003) { |h, d, p, i| }
      @blockers.each { |b| b.start }
      @w = Castoro::Client::TimeslideSender.new(
        @logger,
        @my_host,
        @my_ports,
        @destinations,
        @expire,
        @request_interval)
    end

    it "should secures 30004 or 30005 ports" do
      @times_of_start_and_stop.times {
        @w.start
        @w.port.should included([30004, 30005])
        @w.stop
      }
    end

    after do
      @w.stop rescue nil
      @w = nil
      @blockers.each { |b| b.stop rescue nil }
      @blockers.each { |b| b = nil }
    end
  end

  context "when port number 30003, 30005 is blocked" do
    before do
      @blockers = []
      @blockers << Castoro::Receiver::UDP.new(@logger, 30003) { |h, d, p, i| }
      @blockers << Castoro::Receiver::UDP.new(@logger, 30005) { |h, d, p, i| }
      @blockers.each { |b| b.start }
      @w = Castoro::Client::TimeslideSender.new(
        @logger,
        @my_host,
        @my_ports,
        @destinations,
        @expire,
        @request_interval)
    end

    it "should secures 30004 ports" do
      @times_of_start_and_stop.times {
        @w.start
        @w.port.should == 30004
        @w.stop
      }
    end

    after do
      @w.stop rescue nil
      @w = nil
      @blockers.each { |b| b.stop rescue nil }
      @blockers.each { |b| b = nil }
    end
  end

  context "when port number 30003, 30004, 30005 is blocked" do
    before do
      @blockers = []
      @blockers << Castoro::Receiver::UDP.new(@logger, 30003) { |h, d, p, i| }
      @blockers << Castoro::Receiver::UDP.new(@logger, 30004) { |h, d, p, i| }
      @blockers << Castoro::Receiver::UDP.new(@logger, 30005) { |h, d, p, i| }
      @blockers.each { |b| b.start }
      @w = Castoro::Client::TimeslideSender.new(
        @logger,
        @my_host,
        @my_ports,
        @destinations,
        @expire,
        @request_interval)
    end

    it "should not be able to #start" do
      @times_of_start_and_stop.times {
        Proc.new {
          @w.start
        }.should raise_error(Castoro::ClientError)
        @w.alive?.should be_false
      }
    end

    after do
      @w.stop rescue nil
      @w = nil
      @blockers.each { |b| b.stop rescue nil }
      @blockers.each { |b| b = nil }
    end
  end

  context "when the logger argument is omitted." do
    before do
      @w = Castoro::Client::TimeslideSender.new(
        nil,
        @my_host,
        @my_ports,
        @destinations,
        @expire,
        @request_interval)
    end

    it "should logger equals NilLogger" do
      l = @w.instance_variable_get :@logger
      l.should_not be_nil
      logdev = l.instance_variable_get :@logdev
      logdev.should be_nil
    end

    it "should alive? false" do
      @w.alive?.should be_false
    end

    it "should not be able to stop" do
      Proc.new {
        @w.stop
      }.should raise_error(Castoro::ClientError)
    end

    it "sid should 0" do
      @w.sid.should == 0
    end

    it "should not be able to #send" do
      Proc.new {
        @w.send(Castoro::Protocol::Command::Nop.new)
      }.should raise_error(Castoro::ClientError, "timeslide sender is not started.")
    end

    it "should be able to #restart" do
      @w.alive?.should == false
      @w.restart
      @w.alive?.should == true
    end

    context "when start" do
      before do
        @w.start
        @n = Castoro::Protocol::Command::Nop.new
      end

      it "should alive? true" do
        @w.alive?.should be_true
      end

      it "should not be able to start" do
        Proc.new {
          @w.start
        }.should raise_error(Castoro::ClientError)
      end

      it "#send should be able to be executed normally. and times of send equals sid" do
        expected = Castoro::Protocol::Response::Nop.new(nil).to_s
        @times_of_send.times {
          @w.send(@n).to_s.should == expected
        }
        @w.sid.should == @times_of_send
      end

      it "should be able to #restart" do
        @w.alive?.should == true
        @w.restart
        @w.alive?.should == true
      end

      context "when proces forked" do
        before do
          Process.stub!(:pid).and_return(12345) # fork is camouflaged.
        end

        it "reactivation should be executed by #send" do
          @w.should_receive(:restart).exactly(1)
          @w.send(@n)
        end
      end

      context "when stop" do
        before do
          @w.stop
        end

        it "should alive? false" do
          @w.alive?.should be_false
        end

        it "should threads is nil" do
          threads = @w.instance_variable_get :@threads
          threads.should be_nil
        end

        it "should be able to #restart" do
          @w.alive?.should == false
          @w.restart
          @w.alive?.should == true
        end

        after do
          #
        end
      end

    end

    it "should be able start > stop > start > ..." do
      @times_of_start_and_stop.times {
        @w.start
        @w.stop
      }
    end

    after do
      @w.stop rescue nil
      @w = nil
    end
  end

  after(:all) do
    @gateway_mock.each { |port, mock| mock.stop rescue nil }
    @gateway_mock.each { |port, mock| mock = nil }
    @requester.stop rescue nil
    @requester = nil
  end
end

