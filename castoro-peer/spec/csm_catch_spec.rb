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

require 'castoro-peer/configurations'
require 'castoro-peer/manipulator'

describe Castoro::Peer::Csm::Request::Catch do
  before do
    @conf = mock(Castoro::Peer::Configurations)
  end
  
  context 'when initialize' do
    context 'with(100)' do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Catch.new(100)
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context 'with("")' do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Catch.new("")
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context 'with("/src/path")' do
      before do
        @csm_req = Castoro::Peer::Csm::Request::Catch.new("/src/path")
      end

      it 'should be an instance of Castoro::Peer::Csm::Request::Catch' do
        @csm_req.should be_kind_of Castoro::Peer::Csm::Request::Catch
      end

      it 'should instance valiables be set correctly.' do
        @csm_req.instance_variable_get(:@subcommand).should == "mkdir"
        @csm_req.instance_variable_get(:@user).should == Process.euid
        @csm_req.instance_variable_get(:@group).should ==Process.egid 
        @csm_req.instance_variable_get(:@mode).should == '0755'
        @csm_req.instance_variable_get(:@path1).should == "/src/path"
        @csm_req.instance_variable_get(:@path2).should == ""
      end

      after do
        @csm_req = nil
      end
    end

  end
end

