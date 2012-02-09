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

describe Castoro::Protocol::Command::Alive do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for host."' do
    Proc.new {
      Castoro::Protocol::Command::Alive.new nil, 30, 1000
    }.should raise_error(RuntimeError, "Nil cannot be set for host.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for status."' do
    Proc.new {
      Castoro::Protocol::Command::Alive.new "host100", nil, 1000
    }.should raise_error(RuntimeError, "Nil cannot be set for status.")
  end

  it 'should not be able to create an instance, recause raise RuntimeError "Nil cannot be set for available"' do
    Proc.new {
      Castoro::Protocol::Command::Alive.new "host100", 30, nil
    }.should raise_error(RuntimeError, "Nil cannot be set for available.")
  end

  context 'when initialize, argument for host set "host100", argument for status set 30, argument for available set 1000' do
    it "should be able to an instance of alive command." do
      Castoro::Protocol::Command::Alive.new("host100", 30, 1000).should be_kind_of(Castoro::Protocol::Command::Alive)
    end

    context "when initialized" do
      before do
        @command = Castoro::Protocol::Command::Alive.new "host100", 30, 1000
      end

      it "should be able to get :host ." do
        @command.host.should == "host100"
      end

      it "should be able to get :status ." do
        @command.status.should == 30
      end

      it "should be able to get :available ." do
        @command.available.should == 1000
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","ALIVE",{"host":"host100","status":30,"available":1000}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Alive)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","ALIVE",{"error":{}}]' + "\r\n")
      end

      context "when set error response" do
        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of(Castoro::Protocol::Response::Alive)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","ALIVE",{"error":"Unexpected error!"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Alive do
  context 'when initialize, argument for error set nil' do
    it 'should be able to create an instance of alive response.' do
      Castoro::Protocol::Response::Alive.new(nil).should be_kind_of(Castoro::Protocol::Response::Alive)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Alive.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","ALIVE",{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for erro set "Unexpected error!"' do
    it 'should be able to create an instance of alive error response.' do
      Castoro::Protocol::Response::Alive.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response::Alive)
    end

    context "when initalized" do
      before do
        @response = Castoro::Protocol::Response::Alive.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","ALIVE",{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
