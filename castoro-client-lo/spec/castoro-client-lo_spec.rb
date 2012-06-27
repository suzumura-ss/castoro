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
require 'castoro-client'
require 'fileutils'


def basketkey_to_path(c,t,r, mode)
  "#{$BASEDIR}/#{t}/baskets/#{mode}/#{c}.#{t}.#{r}"
end

def cleanup
  Dir["#{$BASEDIR}/*"].each { |d|
    FileUtils.rm_rf(d)
  }
end


describe Castoro::Client do
  before do
    $BASEDIR = `mktemp -d`.strip
    @c = Castoro::Client.new(:logger=>Logger.new("/dev/null"))
    class << @c
      include Castoro::ClientLocal
    end
    @c.basedir = $BASEDIR
    @c.http_port = 40000
  end

  context "when not open" do
    it "should be fail when #create" do
      lambda{ @c.create "1.1.1" }.should raise_error(Castoro::ClientError)
    end

    it "should be fail when #delete" do
      lambda{ @c.delete "1.1.1" }.should raise_error(Castoro::ClientError)
    end

    it "should be fail when #get" do
      lambda{ @c.get "1.1.1" }.should raise_error(Castoro::ClientError)
    end
  end

  context "" do
    before do
      @c.open
      @w = basketkey_to_path(1,1,1,"w")
      @a = basketkey_to_path(1,1,1,"a")
      @d = basketkey_to_path(1,1,1,"d")
    end

    context "when use #create" do
      before do
        cleanup 
      end

      it "should be fail without block" do
        lambda{ @c.create "1.1.1" }.should raise_error(Castoro::ClientError)
      end

      it "should be success with block" do
        k = nil
        @c.create("1.1.1") {|h,p|
          k = [h, p, File.directory?(@w)]
        }
        k.should == ["localhost:40000", @w, true]
        File.directory?(@w).should be_false
        File.directory?(@a).should be_true
      end

      it "should be fail when same basket" do
        @c.create("1.1.1"){}
        lambda{ @c.create("1.1.1"){} }.should raise_error(Castoro::ClientError)
        File.directory?(@w).should be_false
        File.directory?(@a).should be_true
      end

      it "should be drop directory when cancel" do
        lambda{ @c.create("1.1.1") {
          raise Errno::EACCES
        }}.should raise_error(Errno::EACCES)
        File.directory?(@w).should be_false
        File.directory?(@a).should be_false
      end

      it "should be return port 80" do
        @c.http_port = 80
        k = nil
        @c.create("1.1.1") {|h,p|
          k = [h, p, File.directory?(@w)]
        }
        k.should == ["localhost", @w, true]
      end

      after do
        cleanup
      end
    end

    context "when use #get" do
      before do
        cleanup
        @c.create("1.1.1"){}
      end

      it "should be fail when not exist" do
        lambda{ @c.get "1.1.2" }.should raise_error(Castoro::ClientError)
      end

      it "should be success when exist" do
        @c.get("1.1.1").should == {"localhost:40000"=>@a}
      end

      it "should be success with port 80 when exist" do
        @c.http_port = 80
        @c.get("1.1.1").should == {"localhost"=>@a}
      end

      after do
        cleanup
      end
    end

    context "when use #delete" do
      before do
        cleanup
        @c.create("1.1.1") {}
      end

      it "should be success when not exist" do
        @c.delete("1.1.2").should be_nil
      end

      it "should be success when exist" do
        @c.delete("1.1.1").should be_nil
        File.directory?(@a).should be_false
        File.directory?(@d).should be_true
      end

      after do
        cleanup
      end
    end

    after do
      @c.close
    end
  end

  after do
    FileUtils.rm_rf($BASEDIR)
  end
end
