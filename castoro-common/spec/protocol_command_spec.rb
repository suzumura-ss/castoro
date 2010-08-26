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


describe Castoro::Protocol::Command do

  context 'when Protocol::Command::Nop and Protocol::Command::Delete commands are initialized' do
    it 'should be able to use #== and return false.' do
      nop = Castoro::Protocol::Command::Nop.new
      basket = "987654321.1.2".to_basket
      delete = Castoro::Protocol::Command::Delete.new(basket)
      (nop == delete).should be_false
    end
  end

  context 'when tw Protocol::Command::Nop commands are initialized' do
    it 'should be able to use #== and return true.' do
      nop1 = Castoro::Protocol::Command::Nop.new
      nop2 = Castoro::Protocol::Command::Nop.new
      (nop1 == nop2).should be_true
    end
  end

  context 'when two Protocol::Command::Create commands are initialized with same arguments' do
    it 'should be able to use #== and return true.' do
      basket = "987654321.1.2".to_basket
      create1 = Castoro::Protocol::Command::Create.new(basket, {"length" => "12345", "class" => 1})
      create2 = Castoro::Protocol::Command::Create.new(basket, {"length" => "12345", "class" => 1})
      (create1 == create2).should be_true
    end
  end

  context 'when two Protocol::Command::Create commands are initialized with different arguments' do
    it 'should be able to use #== and return false.' do
      basket = "987654321.1.2".to_basket
      create1 = Castoro::Protocol::Command::Create.new(basket, {"length" => "12345", "class" => 1})
      create2 = Castoro::Protocol::Command::Create.new(basket, {"length" => "54321", "class" => 2})
      (create1 == create2).should be_false
    end
  end


  context 'in case of opecode is "NOP"' do
    context 'when argument for Protocol::Command::Nop#new is' do
      context '()' do
        it 'should return an instance of Command::Nop .' do
          command = Castoro::Protocol::Command::Nop.new()
          command.should be_kind_of Castoro::Protocol::Command::Nop
        end

        it 'should be able to use #to_s' do
          command = Castoro::Protocol::Command::Nop.new()
          JSON.parse(command.to_s).should == JSON.parse('["1.1","C","NOP",{}]' + "\r\n")
        end
      end
    end
  end

  context 'in case of opecode is "CREATE"' do
    context 'when argument for Protocol::Command::Create#new is ' do
      context '(nil, {"length" => "12345","class" => 1})' do
        it "should raise Castoro::BasketKeyError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Create.new(nil, {"length" => "12345", "class" => 1})
          }.should raise_error(Castoro::BasketKeyError)
        end
      end

      context '(basket, nil) basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of hints" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Create.new(basket, nil)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, {"length" => "12345"}) basket => 987654321.1.2,length => 12345 ' do
        it 'should raise RuntimeError because of lack of hints[":class"]' do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Create.new(basket, {"length" => "12345"})
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end


      context '(basket, {"length" => "12345", "class" => 1}) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Create.new(basket, {"length" => "12345", "class" => 1})
        end

        it "should return an instance of Command::Create." do
          @command.should be_kind_of Castoro::Protocol::Command::Create
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to get :hints ." do
          @command.hints.should == {"length"=>12345, "class"=>"1"}
        end

        it "should be able to use Create#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":12345,"class":"1"}}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Create
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":{}}]'+ "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Create
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == JSON.parse('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Finalize"' do
    context 'when argument for Protocol::Command::Finalize#new is ' do
      context '(nil, , "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")' do
        it "should raise Castoro::BasketKeyError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Finalize.new(nil, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(Castoro::BasketKeyError)
        end
      end

      context '(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2") basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of host" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Finalize.new(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host101", nil) basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of path" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Finalize.new(basket, "host101", nil)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host100", {"length" => "12345", "class" => 1}) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Finalize.new(basket, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
        end

        it "should return an instance of Command::Finalize." do
          @command.should be_kind_of Castoro::Protocol::Command::Finalize
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to get :host ." do
          @command.host.should == "host100"
        end

        it "should be able to get :path ." do
          @command.path.should == "/expdsk/1/baskets/a/0/987/654/321.1.2"
        end

        it "should be able to use Finalize#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Finalize
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","FINALIZE",{"basket":null,"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Finalize
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Cancel"' do
    context 'when argument for Protocol::Command::Cancel#new is ' do
      context '(nil, , "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")' do
        it "should raise Castoro::BasketKeyError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Cancel.new(nil, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(Castoro::BasketKeyError)
        end
      end

      context '(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2") basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of host" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Cancel.new(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host101", nil) basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of path" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Cancel.new(basket, "host101", nil)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host100", {"length" => "12345", "class" => 1}) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Cancel.new(basket, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
        end

        it "should return an instance of Command::Cancel." do
          @command.should be_kind_of Castoro::Protocol::Command::Cancel
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to get :host ." do
          @command.host.should == "host100"
        end

        it "should be able to get :path ." do
          @command.path.should == "/expdsk/1/baskets/a/0/987/654/321.1.2"
        end

        it "should be able to use Cancel#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Cancel
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Cancel
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Get"' do
    context 'when argument for Protocol::Command::Get#new is ' do
      context '(nil)' do
        it "should raise Castoro::BasketKeyError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Get.new(nil)
          }.should raise_error(Castoro::BasketKeyError)
        end
      end

      context '(basket) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Get.new(basket)
        end

        it "should return an instance of Command::Get." do
          @command.should be_kind_of Castoro::Protocol::Command::Get
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to use Get#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","GET",{"basket":"987654321.1.2"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Get
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Get
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Delete"' do
    context 'when argument for Protocol::Command::Delete#new is ' do
      context '(nil)' do
        it "should raise Castoro::BasketKeyError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Delete.new(nil)
          }.should raise_error(Castoro::BasketKeyError)
        end
      end

      context '(basket) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Delete.new(basket)
        end

        it "should return an instance of Command::Delete." do
          @command.should be_kind_of Castoro::Protocol::Command::Delete
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to use Delete#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","DELETE",{"basket":"987654321.1.2"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Delete
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","DELETE",{"basket":null,"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Delete
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Insert"' do
    context 'when argument for Protocol::Command::Insert#new is ' do
      context '(nil, , "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")' do
        it "should raise Castoro::BasketKeyError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Insert.new(nil, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(Castoro::BasketKeyError)
        end
      end

      context '(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2") basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of host" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Insert.new(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host101", nil) basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of path" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Insert.new(basket, "host101", nil)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host100", {"length" => "12345", "class" => 1}) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Insert.new(basket, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
        end

        it "should return an instance of Command::Insert." do
          @command.should be_kind_of Castoro::Protocol::Command::Insert
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to get :host ." do
          @command.host.should == "host100"
        end

        it "should be able to get :path ." do
          @command.path.should == "/expdsk/1/baskets/a/0/987/654/321.1.2"
        end

        it "should be able to use Insert#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Insert
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse( '["1.1","R","INSERT",{"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Insert
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","INSERT",{"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Drop"' do
    context 'when argument for Protocol::Command::Insert#new is ' do
      context '(nil, , "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")' do
        it "should raise RuntimeError because of lack of basket" do
          Proc.new {
            Castoro::Protocol::Command::Drop.new(nil, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2") basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of host" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Drop.new(basket, nil, "/expdsk/1/baskets/a/0/987/654/321.1.2")
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host101", nil) basket => 987654321.1.2' do
        it "should raise RuntimeError because of lack of path" do
          basket = "987654321.1.2".to_basket
          Proc.new {
            Castoro::Protocol::Command::Drop.new(basket, "host101", nil)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '(basket, "host100", {"length" => "12345", "class" => 1}) basket => 987654321.1.2' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Drop.new(basket, "host100", "/expdsk/1/baskets/a/0/987/654/321.1.2")
        end

        it "should return an instance of Command::Drop." do
          @command.should be_kind_of Castoro::Protocol::Command::Drop
        end

        it "should be able to get :basket ." do
          basket = @command.basket
          basket.should be_kind_of Castoro::BasketKey
          basket.to_s.should == "987654321.1.2"
        end

        it "should be able to get :host ." do
          @command.host.should == "host100"
        end

        it "should be able to get :path ." do
          @command.path.should == "/expdsk/1/baskets/a/0/987/654/321.1.2"
        end

        it "should be able to use Drop#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Drop
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","DROP",{"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Drop
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","DROP",{"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end


  context 'in case of opecode is "Alive"' do
    context 'when argument for Protocol::Command::Alive#new is ' do
      context '(nil, 30, 1000)' do
        it "should raise RuntimeError because of lack of host" do
          Proc.new {
            Castoro::Protocol::Command::Alive.new(nil, 30, 1000)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '("host100", nil, 1000)' do
        it "should raise RuntimeError because of lack of status" do
          Proc.new {
            Castoro::Protocol::Command::Alive.new("host100", nil, 1000)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '("host100", 30, nil)' do
        it "should raise RuntimeError because of lack of available" do
          Proc.new {
            Castoro::Protocol::Command::Alive.new("host100", 30, nil)
          }.should raise_error(RuntimeError) #TODO RuntimeError should be specified?
        end
      end

      context '("host100", 30, 1000)' do
        before do
          basket = "987654321.1.2".to_basket
          @command = Castoro::Protocol::Command::Alive.new("host100", 30, 1000)
        end

        it "should return an instance of Command::Alive." do
          @command.should be_kind_of Castoro::Protocol::Command::Alive
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

        it "should be able to use Alive#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","ALIVE",{"host":"host100","status":30,"available":1000}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Alive
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","ALIVE",{"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Alive
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","ALIVE",{"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end

  context 'in case of opecode is "STATUS"' do
    context 'when argument for Protocol::Command::Status#new is ' do
      context '["1.1","C","STATUS",{}]' do
        before do
          @command = Castoro::Protocol.parse '["1.1","C","STATUS",{}]'
        end

        it "should return an instance of Command::Status." do
          @command.should be_kind_of Castoro::Protocol::Command::Status
        end

        it "should be able to use Status#to_s and return json data." do
          JSON.parse(@command.to_s).should == 
            JSON.parse('["1.1","C","STATUS",{}]' + "\r\n")
        end

        it "should be able to return error_response without argument." do
          error_res = @command.error_response
          error_res.should be_kind_of Castoro::Protocol::Response::Status
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","STATUS",{"status":{},"error":{}}]' + "\r\n")
        end

        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of Castoro::Protocol::Response::Status
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should == 
            JSON.parse('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
        end

        after do
          @command = nil
        end
      end
    end
  end

end
