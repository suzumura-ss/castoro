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

UDP_PORT     = 30150

describe Castoro::Receiver::UDP do
  context "when port argument is zero or negative number." do
    it "should raise Castoro::Receiver::ReceiverError" do
      Proc.new {
        Castoro::Receiver::UDP.new(nil, 0)
      }.should raise_error(Castoro::Receiver::ReceiverError)
      Proc.new {
        Castoro::Receiver::UDP.new(nil, -1)
      }.should raise_error(Castoro::Receiver::ReceiverError)
      Proc.new {
        Castoro::Receiver::UDP.new(nil, "foo")
      }.should raise_error(Castoro::Receiver::ReceiverError)
    end
  end

  context "when the logger, thread_count, subscriber argument is omitted." do
    before do
      @r = Castoro::Receiver::UDP.new(nil, UDP_PORT)
    end

    it "should logger equals NilLogger" do
      l = @r.instance_variable_get :@logger
      logdev = l.instance_variable_get :@logdev
      logdev.should be_nil
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
      @r = Castoro::Receiver::UDP.new(nil, UDP_PORT)
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
      @r = Castoro::Receiver::UDP.new(nil, UDP_PORT)
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

end

