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

describe Castoro::Protocol::Command::Insert do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for host."' do
    Proc.new {
      Castoro::Protocol::Command::Insert.new "1.2.3", nil, "/host/1.2.3"
    }.should raise_error(RuntimeError, "Nil cannot be set for host.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for path."' do
    Proc.new {
      Castoro::Protocol::Command::Insert.new "1.2.3", "host101", nil
    }.should raise_error(RuntimeError, "Nil cannot be set for path.")
  end

  context 'when initailize, argument for basket set "1.2.3", argument for host set "host100", argument for path set "/path/1.2.3"' do
    it "should be able to create an instance of insert command." do
      Castoro::Protocol::Command::Insert.new("1.2.3", "host100", "/path/1.2.3").should be_kind_of(Castoro::Protocol::Command::Insert)
    end

    context "when initialized" do
      before do
        @command = Castoro::Protocol::Command::Insert.new "1.2.3", "host100", "/path/1.2.3"
      end

      it "should be able to get :basket ." do
        basket = @command.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it "should be able to get :host ." do
        @command.host.should == "host100"
      end

      it "should be able to get :path ." do
        @command.path.should == "/path/1.2.3"
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","INSERT",{"basket":"1.2.3","host":"host100","path":"/path/1.2.3"}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Insert)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse( '["1.1","R","INSERT",{"error":{}}]' + "\r\n")
      end

      context "when set error response" do
        it "should be able to return error_response with argument." do
          error_res = @command.error_response "Unexpected error!"
          error_res.should be_kind_of(Castoro::Protocol::Response::Insert)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","INSERT",{"error":"Unexpected error!"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Insert do
  context 'when initialize, argument for error set nil' do
    it 'should be able to create an instance of insert response.' do
      Castoro::Protocol::Response::Insert.new(nil).should be_kind_of(Castoro::Protocol::Response::Insert)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Insert.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","INSERT",{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!"' do
    it 'should be able to create an instance of insert error response.' do
      Castoro::Protocol::Response::Insert.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response::Insert)
    end

    context 'when initalized' do
      before do
        @response = Castoro::Protocol::Response::Insert.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","INSERT",{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
