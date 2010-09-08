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


describe Castoro::Protocol::Response do

  context 'when Protocol::Response::Nop and Protocol::Response::Delete responses are initialized' do
    it 'should be able to use #== and return false.' do
      nop = Castoro::Protocol::Response::Nop.new nil
      basket = "987654321.1.2".to_basket
      delete = Castoro::Protocol::Response::Delete.new(nil, basket)
      (nop == delete).should be_false
    end
  end

  context 'when Protocol::Response::Create and Protocol::Response::Create::Gateway responses are initialized' do
    context 'with error' do
      it 'should be able to use #== and return false.' do
        hosts = ["host101","host102","host100"]
        basket = "123456789.1.2".to_basket
        create = Castoro::Protocol::Response::Create.new("erro", basket)
        create_gw = Castoro::Protocol::Response::Create::Gateway.new("error", basket, hosts)
        (create == create_gw).should be_false
      end
    end

    context 'without error' do
      it 'should be able to use #== and return false.' do
        hosts = ["host101","host102","host100"]
        basket = "123456789.1.2".to_basket
        create = Castoro::Protocol::Response::Create.new(nil, basket)
        create_gw = Castoro::Protocol::Response::Create::Gateway.new(nil, basket, hosts)
        (create == create_gw).should be_false
      end
    end
  end

  context 'when two Protocol::Response::Nop responses are initialized' do
    it 'should be able to use #== and return true.' do
      nop1 = Castoro::Protocol::Response::Nop.new "Unexpected error!"
      nop2 = Castoro::Protocol::Response::Nop.new "Unexpected error!"
      (nop1 == nop2).should be_true
    end
  end

  context 'when two Protocol::Response::Create::Gateway responses are initialized with same arguments' do
    context 'with error' do
      it 'should be able to use #== and return true.' do
        hosts = ["host101","host102","host100"]
        basket = "123456789.1.2".to_basket
        create_gw1 = Castoro::Protocol::Response::Create::Gateway.new("error", basket, hosts)
        create_gw2 = Castoro::Protocol::Response::Create::Gateway.new("error", basket, hosts)
        (create_gw1 == create_gw2).should be_true
      end
    end

    context 'without error' do
      it 'should be able to use #== and return true.' do
        hosts = ["host101","host102","host100"]
        basket = "123456789.1.2".to_basket
        create_gw1 = Castoro::Protocol::Response::Create::Gateway.new(nil, basket, hosts)
        create_gw2 = Castoro::Protocol::Response::Create::Gateway.new(nil, basket, hosts)
        (create_gw1 == create_gw2).should be_true
      end
    end
  end

  context 'when two Protocol::Response::Create::Gateway responses are initialized with different arguments' do
    it 'should be able to use #== and return false.' do
      hosts = ["host101","host102","host100"]
      basket1 = "123456789.1.2".to_basket
      basket2 = "987654321.1.2".to_basket
      create_gw1 = Castoro::Protocol::Response::Create::Gateway.new(nil, basket1, hosts)
      create_gw2 = Castoro::Protocol::Response::Create::Gateway.new(nil, basket2, hosts)
      (create_gw1 == create_gw2).should be_false
    end
  end


  context 'when argument for Protocol::Response#new is' do
    context '(nil)' do
      before do
        @response = Castoro::Protocol::Response.new(nil)
      end

      it 'should return an instance of Response .' do
        @response.should be_kind_of(Castoro::Protocol::Response)
      end

      it 'should be able to use #to_s' do
        JSON.parse(@response.to_s).should == 
          JSON.parse('["1.1","R",null,{}]' + "\r\n")
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end
    end

    context '("Unexpected error!")' do
      before do
        @response = Castoro::Protocol::Response.new("Unexpected error!")
      end

      it 'should return an instance of Response .' do
        @response.should be_kind_of(Castoro::Protocol::Response)
      end

      it 'should be able to use #to_s' do
        JSON.parse(@response.to_s).should == 
          JSON.parse('["1.1","R",null,{"error":"Unexpected error!"}]' + "\r\n")
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end
    end
  end

  context 'in case of opecode is "NOP"' do
    context 'when argument for Protocol::Response::Nop#new is' do
      context '(nil)' do
        before do
          @response = Castoro::Protocol::Response::Nop.new(nil)
        end

        it 'should return an instance of Response::Nop .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Nop)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","NOP",{}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end
      end

      context '("Unexpected error!")' do
        before do
          @response = Castoro::Protocol::Response::Nop.new("Unexpected error!")
        end

        it 'should return an instance of Response::Nop .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Nop)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","NOP",{"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end
      end
    end
  end


  context 'in case of opecode is "CREATE"' do
    context 'when argument for Protocol::Response::Create#new is' do
      context '(nil, basket) basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create.new(nil, basket)
        end

        it 'should return an instance of Response::Create .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":"123456789.1.2"}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end
      end

      context '("error":"Unexpected error!", basket) basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create.new("Unexpected error!", basket)
        end

        it 'should return an instance of Response::Create .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end

      context '("error":"Unexpected error!")' do
        before do
          @response = Castoro::Protocol::Response::Create.new("Unexpected error!", nil)
        end

        it 'should return an instance of Response::Create .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end
    end

    context 'when argument for Protocol::Response::Create::Gateway#new is' do
      context '(nil, basket, hosts) basket=>"123456789.1.2", hosts=>["host101","host102","host100"]' do
        before do
          hosts = ["host101","host102","host100"]
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Gateway.new(nil, basket, hosts)
        end

        it 'should return an instance of Response::Create::Gateway .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end

        it 'should be able to get :hosts' do
          @response.hosts.should == ["host101","host102","host100"]
        end

        it 'should be able to use #[](index)' do
          @response[0].should == "host101"
          @response[1].should == "host102"
          @response[2].should == "host100"
          @response.[](0).should == "host101"
          @response.[](1).should == "host102"
          @response.[](2).should == "host100"
        end

        it 'should be able to use #each(&block)' do
          hosts = []
          @response.each{|host|
            hosts << host
          }
          hosts.should == ["host101","host102","host100"]
        end
      end

      context '("Unexpected error!", basket, nil) basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Gateway.new("Unexpected error!", basket, nil)
        end

        it 'should return an instance of Response::Create::Gateway .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :hosts' do
          @response.hosts.should be_nil
        end

        it 'should not be able to use #[](index)' do
          Proc.new {
            @response[0]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response[1]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response[2]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](0)
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](1)
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](2)
          }.should raise_error(NoMethodError)
        end

        it 'should not be able to use #each(&block)' do
          Proc.new {
            @response.each{|host|}
          }.should raise_error(NoMethodError)
        end
      end

      context '("Unexpected error!", nil, hosts) hosts=>["host101","host102","host100"]' do
        before do
          hosts = ["host101","host102","host100"]
          @response = Castoro::Protocol::Response::Create::Gateway.new("Unexpected error!", nil, hosts)
        end

        it 'should return an instance of Response::Create::Gateway .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :hosts' do
          @response.hosts.should be_nil
        end

        it 'should not be able to use #[](index)' do
          Proc.new {
            @response[0]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response[1]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response[2]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](0)
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](1)
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](2)
          }.should raise_error(NoMethodError)
        end

        it 'should not be able to use #each(&block)' do
          Proc.new {
            @response.each{|host|}
          }.should raise_error(NoMethodError)
        end
      end

      context '("Unexpected error!", nil, nil)' do
        before do
          @response = Castoro::Protocol::Response::Create::Gateway.new("Unexpected error!", nil, nil)
        end

        it 'should return an instance of Response::Create::Gateway .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :hosts' do
          @response.hosts.should be_nil
        end

        it 'should not be able to use #[](index)' do
          Proc.new {
            @response[0]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response[1]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response[2]
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](0)
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](1)
          }.should raise_error(NoMethodError)
          Proc.new {
            @response.[](2)
          }.should raise_error(NoMethodError)
        end

        it 'should not be able to use #each(&block)' do
          Proc.new {
            @response.each{|host|}
          }.should raise_error(NoMethodError)
        end
      end
    end

    context 'when argument for Protocol::Response::Create::Peer#new is' do
      context '(nil, basket, host, path) basket=>"123456789.1.2", host=>"host101", path=>"/expdsk/1/baskets/w/0/123/456/789.1.2"' do
        before do
          host = "host101"
          path = "/expdsk/1/baskets/w/0/123/456/789.1.2"
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Peer.new(nil, basket, host, path)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":"123456789.1.2","host":"host101","path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end

        it 'should be able to get :host' do
          @response.host.should == "host101"
        end
      end

      context '("Unexpected error!", basket, host, path) basket=>"123456789.1.2", host=>"host101", path=>"/expdsk/1/baskets/w/0/123/456/789.1.2"' do
        before do
          host = "host101"
          path = "/expdsk/1/baskets/w/0/123/456/789.1.2"
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", basket, host, path)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", nil, host, path) host=>"host101", path=>"/expdsk/1/baskets/w/0/123/456/789.1.2"' do
        before do
          host = "host101"
          path = "/expdsk/1/baskets/w/0/123/456/789.1.2"
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", nil, host, path)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", basket, nil, path) basket=>"123456789.1.2", path=>"/expdsk/1/baskets/w/0/123/456/789.1.2"' do
        before do
          path = "/expdsk/1/baskets/w/0/123/456/789.1.2"
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", basket, nil, path)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", basket, host, nil) basket=>"123456789.1.2", host=>"host101"' do
        before do
          host = "host101"
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", basket, host, nil)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", basket, nil, nil) basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", basket, nil, nil)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", nil, nil, path)  path=>"/expdsk/1/baskets/w/0/123/456/789.1.2"' do
        before do
          path = "/expdsk/1/baskets/w/0/123/456/789.1.2"
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", nil, nil, path)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", nil, host, nil) host=>"host101"' do
        before do
          host = "host101"
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", nil, host, nil)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end

      context '("Unexpected error!", nil, nil, nil) host=>"host101"' do
        before do
          @response = Castoro::Protocol::Response::Create::Peer.new("Unexpected error!", nil, nil, nil)
        end

        it 'should return an instance of Response::Create::Peer .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :host' do
          @response.host.should be_nil
        end
      end
    end
  end


  context 'in case of opecode is "FINALIZE"' do
    context 'when argument for Protocol::Response::Finalize#new is' do
      context '(nil, basket)  basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Finalize.new(nil, basket)
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Finalize' do
          @response.should be_kind_of(Castoro::Protocol::Response::Finalize)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end
      end

      context '("Unexpected error!", basket)  basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Finalize.new("Unexpected error!", basket)
        end

        it 'should return an instance of Castoro::Protocol::Response::Finalize .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Finalize)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end

      context '("Unexpected error!", nil)' do
        before do
          @response = Castoro::Protocol::Response::Finalize.new("Unexpected error!", nil)
        end

        it 'should return an instance of Castoro::Protocol::Response::Finalize .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Finalize)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end
    end
  end


  context 'in case of opecode is "CANCEL"' do
    context 'when argument for Protocol::Response::Cancel#new is' do
      context '(nil, basket)  basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Cancel.new(nil, basket)
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Cancel' do
          @response.should be_kind_of(Castoro::Protocol::Response::Cancel)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CANCEL",{"basket":"123456789.1.2"}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end
      end

      context '("Unexpected error!", basket)  basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Cancel.new("Unexpected error!", basket)
        end

        it 'should return an instance of Castoro::Protocol::Response::Cancel .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Cancel)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end

      context '("Unexpected error!", nil)' do
        before do
          @response = Castoro::Protocol::Response::Cancel.new("Unexpected error!", nil)
        end

        it 'should return an instance of Castoro::Protocol::Response::Cancel .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Cancel)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end
    end
  end


  context 'in case of opecode is "GET"' do
    context 'when argument for Protocol::Response::Get#new is' do
      context '(nil, basket, paths)  basket=>"123456789.1.2" paths=>{"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"}' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Get.new(nil, basket, {"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"})
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Get' do
          @response.should be_kind_of(Castoro::Protocol::Response::Get)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should ==
            JSON.parse('["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end

        it 'should be able to get :paths' do
          @response.paths.should == {"host1"=>"path1/2/3/4", "host2"=>"path5/6/7/8"}
        end
      end

      context '("Unexpected error!", basket, paths)  basket=>"123456789.1.2" paths=>{"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"}' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Get.new("Unexpected error!", basket, {"host1"=>"path1/2/3/4","host2"=>"path5/6/7/8"})
        end

        it 'should return an instance of Castoro::Protocol::Response::Get .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Get)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should ==
            JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :paths' do
          @response.paths.should == {}
        end
      end

      context '("Unexpected error!", nil, nil)' do
        before do
          @response = Castoro::Protocol::Response::Get.new("Unexpected error!", nil, nil)
        end

        it 'should return an instance of Castoro::Protocol::Response::Get .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Get)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should ==
            JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end

        it 'should not be able to get :paths' do
          @response.paths.should =={}
        end

      end
    end
  end


  context 'in case of opecode is "DELETE"' do
    context 'when argument for Protocol::Response::Delete#new is' do
      context '(nil, basket)  basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Delete.new(nil, basket)
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Delete' do
          @response.should be_kind_of(Castoro::Protocol::Response::Delete)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","DELETE",{"basket":"123456789.1.2"}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to get :basket' do
          basket = @response.basket
          basket.should be_kind_of(Castoro::BasketKey)
          basket.to_s.should == "123456789.1.2"
        end
      end

      context '("Unexpected error!", basket)  basket=>"123456789.1.2"' do
        before do
          basket = "123456789.1.2".to_basket
          @response = Castoro::Protocol::Response::Delete.new("Unexpected error!", basket)
        end

        it 'should return an instance of Castoro::Protocol::Response::Delete .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Delete)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end

      context '("Unexpected error!", nil)' do
        before do
          @response = Castoro::Protocol::Response::Delete.new("Unexpected error!", nil)
        end

        it 'should return an instance of Castoro::Protocol::Response::Delete .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Delete)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to get :basket' do
          @response.basket.should be_nil
        end
      end
    end
  end


  context 'in case of opecode is "Insert"' do
    context 'when argument for Protocol::Response::Insert#new is' do
      context '(nil)' do
        before do
          @response = Castoro::Protocol::Response::Insert.new(nil)
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Insert' do
          @response.should be_kind_of(Castoro::Protocol::Response::Insert)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","INSERT",{}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

      end

      context '("Unexpected error!")' do
        before do
          @response = Castoro::Protocol::Response::Insert.new("Unexpected error!")
        end

        it 'should return an instance of Castoro::Protocol::Response::Insert .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Insert)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","INSERT",{"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end
      end
    end
  end


  context 'in case of opecode is "Drop"' do
    context 'when argument for Protocol::Response::Drop#new is' do
      context '(nil)' do
        before do
          @response = Castoro::Protocol::Response::Drop.new(nil)
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Drop' do
          @response.should be_kind_of(Castoro::Protocol::Response::Drop)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","DROP",{}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

      end

      context '("Unexpected error!")' do
        before do
          @response = Castoro::Protocol::Response::Drop.new("Unexpected error!")
        end

        it 'should return an instance of Castoro::Protocol::Response::Drop .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Drop)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","DROP",{"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end
      end
    end
  end


  context 'in case of opecode is "Alive"' do
    context 'when argument for Protocol::Response::Alive#new is' do
      context '(nil)' do
        before do
          @response = Castoro::Protocol::Response::Alive.new(nil)
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Alive' do
          @response.should be_kind_of(Castoro::Protocol::Response::Alive)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","ALIVE",{}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

      end

      context '("Unexpected error!")' do
        before do
          @response = Castoro::Protocol::Response::Alive.new("Unexpected error!")
        end

        it 'should return an instance of Castoro::Protocol::Response::Alive .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Alive)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","ALIVE",{"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end
      end
    end
  end


  context 'in case of opecode is "Status"' do
    context 'when argument for Protocol::Response::Status#new is' do
      context 'invalid (status is not a Hash.)' do
        before do
          # nothing
        end

        it 'should raise error. (when status = "status")' do
          Proc.new{
            @response = Castoro::Protocol::Restponse::Status.new(nil,"status")
          }.should raise_error(NameError)
        end

        it 'should raise error. (when status = 123)' do
          Proc.new{
            @response = Castoro::Protocol::Restponse::Status.new(nil,123)
          }.should raise_error(NameError)
        end

        it 'should raise error. (when status = ["status"])' do
          Proc.new{
            @response = Castoro::Protocol::Restponse::Status.new(nil,["status"])
          }.should raise_error(NameError)
        end

        after do
          @response = nil
        end
      end

      context '(nil, {})' do
        before do
          @response = Castoro::Protocol::Response::Status.new(nil, {})
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Status' do
          @response.should be_kind_of(Castoro::Protocol::Response::Status)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","STATUS",{"status":{}}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to use Status#method_missing' do
          @response.key?("condition").should be_false
        end

        after do
          @response = nil
        end
      end

      context '(nil, {"condition" => "fine"})' do
        before do
          @response = Castoro::Protocol::Response::Status.new(nil, {"condition" => "fine"})
        end

        it 'should be able to create an instance of Castoro::Protocol::Response::Status' do
          @response.should be_kind_of(Castoro::Protocol::Response::Status)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","STATUS",{"status":{"condition":"fine"}}]' + "\r\n")
        end

        it 'should be #error? false.' do
          @response.error?.should be_false
        end

        it 'should be able to use Status#method_missing' do
          @response.key?("condition").should be_true
        end

        after do
          @response = nil
        end
      end

      context '("Unexpected error!", {})' do
        before do
          @response = Castoro::Protocol::Response::Status.new("Unexpected error!", {})
        end

        it 'should return an instance of Castoro::Protocol::Response::Status .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Status)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to use Status#method_missing' do
          Proc.new{
            @response.key?("condition")
          }.should raise_error(NoMethodError)
        end

        after do
          @response = nil
        end
      end

      context '("Unexpected error!", {"condition" => "fine"})' do
        before do
          @response = Castoro::Protocol::Response::Status.new("Unexpected error!", {"condition" => "fine"})
        end

        it 'should return an instance of Castoro::Protocol::Response::Status .' do
          @response.should be_kind_of(Castoro::Protocol::Response::Status)
        end

        it 'should be able to use #to_s' do
          JSON.parse(@response.to_s).should == 
            JSON.parse('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
        end

        it 'should be #error? true.' do
          @response.error?.should be_true
        end

        it 'should not be able to use Status#method_missing' do
          Proc.new{
            @response.key?("condition")
          }.should raise_error(NoMethodError)
        end

        after do
          @response = nil
        end
      end
    end
  end


end
