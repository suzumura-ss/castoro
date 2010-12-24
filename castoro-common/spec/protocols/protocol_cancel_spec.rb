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

describe Castoro::Protocol::Command::Cancel do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for host."' do
    Proc.new {
      Castoro::Protocol::Command::Cancel.new "1.2.3", nil, "/path/1.2.3"
    }.should raise_error(RuntimeError, "Nil cannot be set for host.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for path."' do
    Proc.new {
      Castoro::Protocol::Command::Cancel.new "1.2.3", "host101", nil
    }.should raise_error(RuntimeError, "Nil cannot be set for path.")
  end

  context 'when initialize, argument for basket set "1.2.3", argument for host set "host100", argument for path set "/path/1.2.3"' do
    it "should be able to create an instance of cancel command." do
      Castoro::Protocol::Command::Cancel.new("1.2.3", "host100", "path/1.2.3").should be_kind_of(Castoro::Protocol::Command::Cancel)
    end

    context "when initialized" do
      before do
        @command = Castoro::Protocol::Command::Cancel.new "1.2.3", "host100", "/path/1.2.3"
      end

      it "should be able to get :basket." do
        basket = @command.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it "should be able to get :host." do
        @command.host.should == "host100"
      end

      it "should be able to get :path." do
        @command.path.should == "/path/1.2.3"
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","CANCEL",{"basket":"1.2.3","host":"host100","path":"/path/1.2.3"}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Cancel)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":{}}]' + "\r\n")
      end

      it "should be able to return error_response with argument." do
        error_res = @command.error_response("Unexpected error!")
        error_res.should be_kind_of(Castoro::Protocol::Response::Cancel)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end

describe Castoro::Protocol::Response::Cancel do
  context 'when initialize, argument for error set nil, argument for basket set "1.2.3"' do
    it 'should be able to create an instance of cancel response.' do
      Castoro::Protocol::Response::Cancel.new(nil, "1.2.3").should be_kind_of(Castoro::Protocol::Response::Cancel)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Cancel.new nil, "1.2.3"
      end

      it 'should be able to get :basket.' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CANCEL",{"basket":"1.2.3"}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!", argument for basket set "1.2.3"' do
    it 'should be able to create an instance of cancel error response.' do
      Castoro::Protocol::Response::Cancel.new("Unexpected error!", "1.2.3").should be_kind_of(Castoro::Protocol::Response::Cancel)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Cancel.new "Unexpected error!", "1.2.3"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should not be able to get :basket.' do
        @response.basket.should be_nil
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
