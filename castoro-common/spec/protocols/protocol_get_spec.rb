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

describe Castoro::Protocol::Command::Get do
  context 'when initialize, argument for basket set "1.2.3"' do
    it "should be able to create an instance of get command." do
      Castoro::Protocol::Command::Get.new("1.2.3").should be_kind_of(Castoro::Protocol::Command::Get)
    end

    describe "#initialize" do
      context "given basket." do
        before do
          @command = Castoro::Protocol::Command::Get.new "1.2.3"
        end

        it "should be able to get :basket." do
          basket = @command.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "1.2.3"
        end

        it "should be able to use #to_s." do
          JSON.parse(@command.to_s).should ==
            JSON.parse('["1.1","C","GET",{"basket":"1.2.3"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of(Castoro::Protocol::Response::Get)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":{}}]' + "\r\n")
        end

        context "when set error response" do
          it "should be able to return error_response with argument." do
            error_res = @command.error_response "Unexpected error!"
            error_res.should be_kind_of(Castoro::Protocol::Response::Get)
            error_res.error?.should be_true
            JSON.parse(error_res.to_s).should ==
              JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
          end
        end
      end

      context "given basket and island." do
        before do
          @command = Castoro::Protocol::Command::Get.new "1.2.4", "abc45678"
        end

        it "basket is '1.2.4'." do
          basket = @command.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "1.2.4"
        end

        it "island is 'abc45678'." do
          island = @command.island
          island.should == "abc45678"
        end

        it "should be able to use #to_s." do
          JSON.parse(@command.to_s).should ==
            JSON.parse('["1.1","C","GET",{"basket":"1.2.4","island":"abc45678"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Get do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for paths"' do
    Proc.new {
      Castoro::Protocol::Response::Get.new nil, "1.2.3", nil
    }.should raise_error(RuntimeError, "paths should be a Hash.")
  end

  describe "#initialize" do
    context "given basket and hosts." do
      before do
        @response = Castoro::Protocol::Response::Get.new(nil, "1.2.3", {"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"})
      end

      it 'basket is "1.2.3".' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'paths is "host1" => "path1/2/3/4", "host2" => "path5/6/7/8".' do
        @response.paths.should == {"host1"=>"path1/2/3/4", "host2"=>"path5/6/7/8"}
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","GET",{"basket":"1.2.3","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]' + "\r\n")
      end
    end

    context "given basket, hosts and island." do
      before do
        @response = Castoro::Protocol::Response::Get.new(nil, "1.2.4", {"host3"=>"path1/2/3/4","host4"=>"path5/6/7/8"}, "abc45678")
      end

      it 'basket is "1.2.4".' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.4"
      end

      it 'paths is "host3" => "path1/2/3/4", "host4" => "path5/6/7/8".' do
        @response.paths.should == {"host3"=>"path1/2/3/4", "host4"=>"path5/6/7/8"}
      end

      it "island is 'abc45678'." do
        island = @command.island
        island.should == "abc45678"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","GET",{"basket":"1.2.4","paths":{"host3":"path1/2/3/4","host4":"path5/6/7/8"},"island":"abc45678"}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!", argument for basket set basket "1.2.3" argument for paths set {"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"}' do
    it 'should be able to create an instance of get error response.' do
      Castoro::Protocol::Response::Get.new("Unexpected error!", "1.2.3", {"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"}).should be_kind_of(Castoro::Protocol::Response::Get)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Get.new "Unexpected error!", "1.2.3", {"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"}
      end

      it 'should not be able to get :basket.' do
        @response.basket.should be_nil
      end

      it 'should not be able to get :paths.' do
        @response.paths.should == {}
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
