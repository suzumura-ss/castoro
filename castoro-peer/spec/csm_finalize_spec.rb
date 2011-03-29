#
#   Finalizeright 2010 Ricoh Company, Ltd.
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

PATH1 = "/src/path"
PATH2 = "/dst/path"

describe Castoro::Peer::Csm::Request::Finalize do
  before do
    @conf  = Castoro::Peer::Configurations.instance
  end
  
  context 'when initialize' do
    context "with(#{PATH1}, 100)" do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Finalize.new(PATH1, 100)
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context "with(100, #{PATH2})" do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Finalize.new(100, PATH2)
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context 'with("")' do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Finalize.new("")
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context "with('', #{PATH2})" do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Finalize.new("", PATH2)
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context "with(#{PATH1}, '')" do
      it 'should raise error' do
        pending "this case should be checked and rescued."
        Proc.new{
          @csm_req = Castoro::Peer::Csm::Request::Finalize.new(PATH1, "")
        }.should raise_error(Castoro::Peer::InternalServerError)
      end
    end

    context "with(#{PATH1}, #{PATH2})" do
      before do
        @csm_req = Castoro::Peer::Csm::Request::Finalize.new(PATH1, PATH2)
      end

      it 'should be an instance of Castoro::Peer::Csm::Request::Finalize' do
        @csm_req.should be_kind_of Castoro::Peer::Csm::Request::Finalize
      end

      it 'should instance valiables be set correctly.' do
        @csm_req.instance_variable_get(:@subcommand).should == "mv"
        @csm_req.instance_variable_get(:@user).should == @conf.Dir_a_user
        @csm_req.instance_variable_get(:@group).should == @conf.Dir_a_group
        @csm_req.instance_variable_get(:@mode).should == @conf.Dir_a_perm
        @csm_req.instance_variable_get(:@path1).should == PATH1
        @csm_req.instance_variable_get(:@path2).should == PATH2
      end

      after do
        @csm_req = nil
      end
    end

  end
end

