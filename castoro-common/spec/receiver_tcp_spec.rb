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

require "socket"

TCP_PORT = 30150

describe Castoro::Receiver::TCP do
  context "when port argument is zero or negative number." do
    it "should raise Castoro::Receiver::ReceiverError" do
      Proc.new {
        Castoro::Receiver::TCP.new(nil, 0)
      }.should raise_error(Castoro::Receiver::ReceiverError)
      Proc.new {
        Castoro::Receiver::TCP.new(nil, -1)
      }.should raise_error(Castoro::Receiver::ReceiverError)
      Proc.new {
        Castoro::Receiver::TCP.new(nil, "foo")
      }.should raise_error(Castoro::Receiver::ReceiverError)
    end
  end

  context "when the logger, thread_count, subscriber argument is omitted." do
    before do
      @r = Castoro::Receiver::TCP.new(nil, TCP_PORT)
    end

    it "should logger equals NilLogger" do
      l = @r.instance_variable_get :@logger
      logdev = l.instance_variable_get :@logdev
      logdev.should be_nil
    end

    it "should thread_count 1" do
      @r.instance_variable_get(:@thread_count).should == 1
    end

    it "should alive? false" do
      @r.alive?.should be_false
    end

    it "should be able start>stop" do
      1000.times {
        @r.start
        @r.stop
      }
    end

    it "should not be able stop" do
      Proc.new { @r.stop }.should raise_error(Castoro::Receiver::ReceiverError)
    end

    after do
      @r.stop if @r.alive? rescue nil
    end
  end

  context "when service started." do
    before do
      @r = Castoro::Receiver::TCP.new(nil, TCP_PORT)
      @r.start
    end

    it "should alive? true" do
      @r.alive?.should be_true
    end

    it "should be able stop" do
      @r.stop
    end

    it "should not be able start" do
      Proc.new { @r.start }.should raise_error(Castoro::Receiver::ReceiverError)
    end

    after do
      @r.stop if @r.alive? rescue nil
    end
  end

  context "when service stopped." do
    before do
      @r = Castoro::Receiver::TCP.new(nil, TCP_PORT)
    end

    it "should alive? false" do
      @r.alive?.should be_false
    end

    it "should be able start" do
      @r.start
    end

    it "should not be able stop" do
      Proc.new { @r.stop }.should raise_error(Castoro::Receiver::ReceiverError)
    end

    after do
      @r.stop if @r.alive? rescue nil
    end
  end

  context "when specified subscriber." do
    before do
      @r = Castoro::Receiver::TCP.new(nil, TCP_PORT, 10) { |command|
        case command
        when Castoro::Protocol::Command::Nop
          Castoro::Protocol::Response::Nop.new nil
        when Castoro::Protocol::Command::Status
          Castoro::Protocol::Response::Status.new nil
        # GET is no definition.
        end
      }
      @r.start
    end

    it "should return valid NOP response" do
      Castoro::Sender::TCP.start(nil, "127.0.0.1", TCP_PORT, 1.0) { |s|
        3000.times {
          cmd = Castoro::Protocol::Command::Nop.new
          res = s.send(cmd, 5.0)
          res.class.should be_eql(Castoro::Protocol::Response::Nop)
          res.error?.should be_false
        }
      }
    end

    it "should return invalid GET response" do
      Castoro::Sender::TCP.start(nil, "127.0.0.1", TCP_PORT, 1.0) { |s|
        3000.times {
          key = Castoro::BasketKey.new(1, 2, 3)
          cmd = Castoro::Protocol::Command::Get.new(key)
          res = s.send(cmd, 5.0)
          res.class.should be_eql(Castoro::Protocol::Response::Get)
          res.error?.should be_true
        }
      }
    end

    after do
      @r.stop if @r.alive? rescue nil
    end
  end
end

