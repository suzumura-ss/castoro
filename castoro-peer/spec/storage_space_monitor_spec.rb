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

require "castoro-peer/storage_space_monitor"

describe Castoro::Peer::StorageSpaceMonitor do
  context "When constructor argument is nil." do
    it "should raise RuntimeError" do
      Proc.new {
        m = Castoro::Peer::StorageSpaceMonitor.new nil
      }.should raise_error(RuntimeError)
    end
  end

  context "When the directory that does not exist is specified" do
    it "should raise RuntimeError" do
      Proc.new {
        m = Castoro::Peer::StorageSpaceMonitor.new "/not/found/directory"
      }.should raise_error(RuntimeError)
    end
  end

  context "When the directory that does exist is specified" do
    before do
      dir = File.dirname(__FILE__)
      @m = Castoro::Peer::StorageSpaceMonitor.new dir
    end

    it "should alive? false" do
      @m.alive?.should be_false
    end

    it "should inaccessible #space_bytes" do
      Proc.new {
        @m.space_bytes
      }.should raise_error(RuntimeError)
    end

    it "should not possible to execute #stop" do
      Proc.new {
        @m.stop
      }.should raise_error(RuntimeError)
    end

    context "When service started" do
      before do
        @m.start
      end

      it "should alive? true" do
        @m.alive?.should be_true
      end

      it "should accessible #space_bytes" do
        @m.space_bytes
      end

      it "should be able to stop" do
        @m.stop
      end

      it "should possible to execute #start" do
        Proc.new {
          @m.start
        }.should raise_error(RuntimeError)
      end

      after do
        @m.stop if @m.alive? rescue nil
      end
    end

    it "should be able to start > stop > start > ..." do
      100.times {
        @m.start
        @m.stop
      }
    end
    
    after do
      @m = nil
    end
  end
end

