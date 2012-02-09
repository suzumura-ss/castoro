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

require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Castoro::Protocol::Command::Nop do
  context 'when initialize' do
    it 'should be able to create an instance of nop command.' do
      Castoro::Protocol::Command::Nop.new.should be_kind_of(Castoro::Protocol::Command::Nop)
    end

    context 'when initialized' do
      it 'should be able to use #to_s' do
        command = Castoro::Protocol::Command::Nop.new
        JSON.parse(command.to_s).should == JSON.parse('["1.1","C","NOP",{}]' + "\r\n")
      end
    end
  end
end

describe Castoro::Protocol::Response::Nop do
  context 'when initialize, argument for error set nil' do
    it 'should be able to create an instance of nop response.' do
      Castoro::Protocol::Response::Nop.new(nil).should be_kind_of(Castoro::Protocol::Response::Nop)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Nop.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","NOP",{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!"' do
    it 'should be able to create an instance of nop error response.' do
      Castoro::Protocol::Response::Nop.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response::Nop)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Nop.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","NOP",{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
