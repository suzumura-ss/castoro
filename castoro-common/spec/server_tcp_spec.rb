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

describe Castoro::Server::TCP do
  before do
    @temp_port = 30150
  end

  context "when the logger argument is omitted." do
    before do
      @s = Castoro::Server::TCP.new(nil, @temp_port)
    end

    it "should logger equals NilLogger" do
      l = @s.instance_variable_get :@logger
      l.should_not be_nil
      logdev = l.instance_variable_get :@logdev
      logdev.should be_nil
    end

    it "should alive? false" do
      @s.alive?.should be_false
    end

    it "should not be able to stop" do
      Proc.new {
        @s.stop
      }.should raise_error Castoro::ServerError
    end

    context "when start" do
      before do
        @s.start
      end

      it "should alive? true" do
        @s.alive?.should be_true
      end

      it "should @tcp_server is valid and opened" do
        tcp_server = @s.instance_variable_get :@tcp_server
        tcp_server.should_not be_nil
        tcp_server.closed?.should be_false
      end

      it "should not be able to start" do
        Proc.new {
          @s.start
        }.should raise_error Castoro::ServerError
      end

      context "when stop" do
        before do
          @s.stop
        end

        it "should alive? false" do
          @s.alive?.should be_false
        end

        it "should @tcp_server is nil" do
          tcp_server = @s.instance_variable_get :@tcp_server
          tcp_server.should be_nil
        end

        after do
          #
        end
      end

    end

    it "should be able start > stop > start > ..." do
      100.times {
        @s.start
        @s.stop
      }
    end

    after do
      @s.stop rescue nil
      @s = nil
    end
  end

end

