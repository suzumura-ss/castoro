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

describe Castoro::Workers do
  context "when the logger argument is omitted, and count is set to 3." do
    before do
      @w = Castoro::Workers.new(nil, 3)
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
      }.should raise_error Castoro::WorkersError
    end

    context "when start" do
      before do
        @w.start
      end

      it "should alive? true" do
        @w.alive?.should be_true
      end

      it "should thread count is 3" do
        threads = @w.instance_variable_get :@threads
        threads.count.should == 3
      end

      it "should not be able to start" do
        Proc.new {
          @w.start
        }.should raise_error Castoro::WorkersError
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

        after do
          #
        end
      end

    end

    it "should be able start > stop > start > ..." do
      100.times {
        @w.start
        @w.stop
      }
    end

    after do
      @w.stop rescue nil
      @w = nil
    end
  end

end

