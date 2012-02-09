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

describe Castoro::Protocol::Command::Island do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for island."' do
    Proc.new {
      Castoro::Protocol::Command::Island.new nil, 30, 1000
    }.should raise_error(RuntimeError, "Nil cannot be set for island.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for storables."' do
    Proc.new {
      Castoro::Protocol::Command::Island.new "host100", nil, 1000
    }.should raise_error(RuntimeError, "Nil cannot be set for storables.")
  end

  it 'should not be able to create an instance, recause raise RuntimeError "Nil cannot be set for capacity"' do
    Proc.new {
      Castoro::Protocol::Command::Island.new "host100", 30, nil
    }.should raise_error(RuntimeError, "Nil cannot be set for capacity.")
  end

  context 'given island, storables and capacity.' do
    it "should be able to an instance of island command." do
      Castoro::Protocol::Command::Island.new("ebcdef01", 30, 1000).should be_kind_of(Castoro::Protocol::Command::Island)
    end

    context "when initialized" do
      before do
        @command = Castoro::Protocol::Command::Island.new "ebcdef10", 30, 1000
      end

      it "island is 'ebcdef10'" do
        @command.island.to_s.should == "ebcdef10"
      end

      it "storables is 30" do
        @command.storables.should == 30
      end

      it "capacity is 1000" do
        @command.capacity.should == 1000
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","ISLAND",{"island":"ebcdef10","storables":30,"capacity":1000}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Island)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","ISLAND",{"error":{}}]' + "\r\n")
      end

      context "when set error response" do
        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of(Castoro::Protocol::Response::Island)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","ISLAND",{"error":"Unexpected error!"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Island do
  context 'when initialize, argument for error set nil' do
    it 'should be able to create an instance of island response.' do
      Castoro::Protocol::Response::Island.new(nil).should be_kind_of(Castoro::Protocol::Response::Island)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Island.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","ISLAND",{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for erro set "Unexpected error!"' do
    it 'should be able to create an instance of island error response.' do
      Castoro::Protocol::Response::Island.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response::Island)
    end

    context "when initalized" do
      before do
        @response = Castoro::Protocol::Response::Island.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","ISLAND",{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end

