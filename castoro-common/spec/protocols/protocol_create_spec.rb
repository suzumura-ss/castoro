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

describe Castoro::Protocol::Command::Create do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for hints"'do
    Proc.new {
      Castoro::Protocol::Command::Create.new "1.2.3", nil
    }.should raise_error(RuntimeError, "hints should be a Hash.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nilcannot be set for class"' do
    Proc.new {
      Castoro::Protocol::Command::Create.new "1.2.3", {"length" => "12345"}
    }.should raise_error(RuntimeError, "Nil cannot be set for class.")
  end

  describe "#initialize" do
    context "given basket." do
      before do
        @command = Castoro::Protocol::Command::Create.new "1.2.3", {"length" => "12345", "class" => 1}
      end

      it "should be able to get :basket." do
        basket = @command.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it "should be able to get :hints." do
        @command.hints.should == {"length"=>12345, "class"=>"1"}
      end

      it "should be able to get hints#klass." do
        @command.hints.klass.should == "1"
      end

      it "should be able to get hints#length." do
        @command.hints.length.should == 12345
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","CREATE",{"basket":"1.2.3","hints":{"length":12345,"class":"1"}}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should == JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":{}}]'+ "\r\n")
      end

      it "should be able to return error_response with argument." do
        error_res = @command.error_response "Unexpected error!"
        error_res.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should == JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
      end
    end

    context "given basket and island." do
      before do
        @command = Castoro::Protocol::Command::Create.new "1.2.3", {"length" => "12345", "class" => 1}, "island" => "abc45678"
      end

      it "basket is '1.2.3'." do
        basket = @command.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it "island is 'abc45678'." do
        island = @command.island
        island.should == "abc45678"
      end

      it "should be able to get :hints." do
        @command.hints.should == {"length"=>12345, "class"=>"1"}
      end

      it "should be able to get hints#klass." do
        @command.hints.klass.should == "1"
      end

      it "should be able to get hints#length." do
        @command.hints.length.should == 12345
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","CREATE",{"basket":"1.2.3","hints":{"length":12345,"class":"1"},"island":"abc45678"}]' + "\r\n")
      end
    end
  end
end

describe Castoro::Protocol::Response::Create do
  it "should be able to create an instance of create response." do
    Castoro::Protocol::Response::Create.new(nil, "1.2.3").should be_kind_of(Castoro::Protocol::Response::Create)
  end

  describe "#initialize" do
    context "given basket" do
      before do
        @response = Castoro::Protocol::Response::Create.new nil, "1.2.3"
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
          JSON.parse('["1.1","R","CREATE",{"basket":"1.2.3"}]' + "\r\n")
      end
    end

    context "given basket and island" do
      before do
        @response = Castoro::Protocol::Response::Create.new nil, "1.2.3", "abc45678"
      end

      it 'basket is "1.2.3".' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'island is "abc45678".' do
        island = @response.island
        islnad.should == "abc45678"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":"1.2.3","island":"abc45678"}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!", argument for basket set "1.2.3"' do
    it 'should be able to create an instance of create error response.' do
      Castoro::Protocol::Response::Create.new("Unexpected error!", "1.2.3").should be_kind_of(Castoro::Protocol::Response::Create)
    end

    context 'when initialized' do
      before do
        @response = Castoro::Protocol::Response::Create.new "Unexpected error!", "1.2.3"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should not be able to get :basket.' do
        @response.basket.should be_nil
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end

describe Castoro::Protocol::Response::Create::Gateway do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for hosts".' do
    Proc.new {
      Castoro::Protocol::Response::Create::Gateway.new nil, "1.2.3", nil
    }.should raise_error(RuntimeError, "Nil cannot be set for hosts.")
  end

  decribe "#initialize" do
    context "given basket and hosts." do
      before do
        @response = Castoro::Protocol::Response::Create::Gateway.new nil, "1.2.3", [ "host100", "host101", "host102" ]
      end

      it 'should be able to get :basket.' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'should be able to get :hosts.' do
        @response.hosts.should == [ "host100", "host101", "host102" ]
      end

      it 'should be able to use #each(&block).' do
        hosts = []
        @response.each{|host|
          hosts << host
        }
        hosts.should == [ "host100", "host101", "host102" ]
      end

      it 'should be able to use #[](index).' do
        @response[0].should == "host100"
        @response[1].should == "host101"
        @response[2].should == "host102"
        @response.[](0).should == "host100"
        @response.[](1).should == "host101"
        @response.[](2).should == "host102"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":"1.2.3","hosts":["host100","host101","host102"]}]' + "\r\n")
      end
    end

    context "given basket, hosts and island." do
      before do
        @response = Castoro::Protocol::Response::Create::Gateway.new nil, "1.2.3", [ "host100", "host101", "host102" ], "abc45678"
      end

      it 'basket is "1.2.3".' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'island is "abc45678".' do
        island = @response.island
        islnad.should == "abc45678"
      end

      it 'hosts is "host100", "host101", "host102".' do
        @response.hosts.should == [ "host100", "host101", "host102" ]
      end

      it 'should be able to use #each(&block).' do
        hosts = []
        @response.each{|host|
          hosts << host
        }
        hosts.should == [ "host100", "host101", "host102" ]
      end

      it 'should be able to use #[](index).' do
        @response[0].should == "host100"
        @response[1].should == "host101"
        @response[2].should == "host102"
        @response.[](0).should == "host100"
        @response.[](1).should == "host101"
        @response.[](2).should == "host102"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":"1.2.3","hosts":["host100","host101","host102"],"island":"abc45678"}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!", argument for basket set "1.2.3", argument for hosts set [ "host100", "host101", "host102" ]' do
    it 'should be able to create an instance of create gateway error response.' do
      Castoro::Protocol::Response::Create::Gateway.new("Unexpected error!", "1.2.3", [ "host100", "host101", "host102" ]).should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Create::Gateway.new "Unexpected error!", "1.2.3", [ "host100", "host101", "host102" ]
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should not be able to get :basket.' do
        @response.basket.should be_nil
      end

      it 'should not be able to get :hosts.' do
        @response.hosts.should be_nil
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end

describe Castoro::Protocol::Response::Create::Peer do
  it 'should not be able to create an instance, bacause raise RuntimeError "Nil cannot be set for host."' do
    Proc.new {
      Castoro::Protocol::Response::Create::Peer.new nil, "1.2.3", nil, "path"
    }.should raise_error(RuntimeError, "Nil cannot be set for host.")
  end

  it 'should not be able to create an instance, bacause raise RuntimeError "Nil cannot be set for path."' do
    Proc.new {
      Castoro::Protocol::Response::Create::Peer.new nil, "1.2.3", "host", nil
    }.should raise_error(RuntimeError, "Nil cannot be set for path.")
  end

  describe "#initialize" do
    it 'should be able to create an instance of create peer response.' do
      Castoro::Protocol::Response::Create::Peer.new(nil, "1.2.3", "host100", "/path/1.2.3").should be_kind_of(Castoro::Protocol::Response::Create::Peer)
    end

    context 'given basket, host and path.' do
      before do
        @response = Castoro::Protocol::Response::Create::Peer.new nil, "1.2.3", "host100", "/path/1.2.3"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to get :basket.' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'should be able to get :host.' do
        @response.host.should == "host100"
      end

      it 'should be able to get :path.' do
        @response.path.should == "/path/1.2.3"
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":"1.2.3","host":"host100","path":"/path/1.2.3"}]' + "\r\n")
      end
    end

    context 'given basket, host, path and island.' do
      before do
        @response = Castoro::Protocol::Response::Create::Peer.new nil, "1.2.3", "host100", "/path/1.2.3", "abc45678"
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to get :basket.' do
        basket = @response.basket
        basket.should be_kind_of(Castoro::BasketKey)
        basket.to_s.should == "1.2.3"
      end

      it 'island is "abc45678".' do
        island = @response.island
        islnad.should == "abc45678"
      end

      it 'should be able to get :host.' do
        @response.host.should == "host100"
      end

      it 'should be able to get :path.' do
        @response.path.should == "/path/1.2.3"
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":"1.2.3","host":"host100","path":"/path/1.2.3","island":"abc45678"}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!", argument for basket set "1.2.3", argument for host set "host100", argument for path set "/path/1.2.3"' do
    it 'should be able to create an instance of create peer error response.' do
      Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", "1.2.3", "host100", "/path/1.2.3").should be_kind_of(Castoro::Protocol::Response::Create::Peer)
    end

    context 'when initialized' do
      before do
       @response = Castoro::Protocol::Response::Create::Peer.new "Unexpected error!", "1.2.3", "host100", "/path/1.2.3"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should not be able to get :basket.' do
        @response.basket.should be_nil
      end

      it 'should not be able to get :host.' do
        @response.host.should be_nil
      end

      it 'should not be able to get :path.' do
        @response.path.should be_nil
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
