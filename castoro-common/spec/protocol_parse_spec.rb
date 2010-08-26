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


describe Castoro::Protocol do
  context 'when argument for Protocol#parse is' do
    context 'Integer' do
      it "should raise Castoro::ProtocolError" do
        Proc.new {
          Castoro::Protocol.parse 123
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context 'Hash' do
      it "should raise Castoro::ProtocolError" do
        Proc.new {
          Castoro::Protocol.parse({:value => "hash"})
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context 'not enough' do
      it "should raise Castoro::ProtocolError" do
        Proc.new {
          Castoro::Protocol.parse '["1.1","C","CREATE"]'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context 'too many ' do
      it "should raise Castoro::ProtocolError" do
        Proc.new {
          Castoro::Protocol.parse '["1.1","C","CREATE","basket":"987654321.1.2","hints":{"length":"12345","class":1}]'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '["1.1","C","NoCommand",{}].' do
      it "should raise Castoro::Protocol Error ." do
        Proc.new{
          Castoro::Protocol.parse '["1.1","C","NoCommand",{}].'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '["1.1","C","Nop",{}].' do
      it "should raise Castoro::Protocol Error ." do
        Proc.new{
          Castoro::Protocol.parse '["1.1","C","Nop",{}].'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '["1.1","R","Nop",{}].' do
      it "should raise Castoro::Protocol Error ." do
        Proc.new{
          Castoro::Protocol.parse '["1.1","R","Nop",{}].'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '["1.1","D","Nop",{}].' do
      it "should raise Castoro::Protocol Error ." do
        Proc.new{
          Castoro::Protocol.parse '["1.1","D","Nop",{}].'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '["1.1","C","NOP",{}]' do
      it 'should return an instance of Command::Nop .' do
        command = Castoro::Protocol::parse'["1.1","C","NOP",{}]'
        command.should be_kind_of Castoro::Protocol::Command::Nop
        command.to_s.should == '["1.1","C","NOP",{}]' + "\r\n"
      end
    end

    context '["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]' do
      it "should return an instance of Command::Create." do
        command = Castoro::Protocol.parse '["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
        command.should be_kind_of Castoro::Protocol::Command::Create
        command.to_s.should == '["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":12345,"class":"1"}}]' + "\r\n"
      end
    end

    context '["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it "should return an instance of Command::Finalize." do
        command = Castoro::Protocol.parse '["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Command::Finalize
        command.to_s.should == '["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it "should return an instance of Command::Cancel." do
        command = Castoro::Protocol.parse '["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Command::Cancel
        command.to_s.should == '["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","C","GET",{"basket":"987654321.1.2"}]' do
      it "should return an instance of Command::Get." do
        command = Castoro::Protocol.parse '["1.1","C","GET",{"basket":"987654321.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Command::Get
        command.to_s.should == '["1.1","C","GET",{"basket":"987654321.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","C","DELETE",{"basket":"987654321.1.2"}]' do
      it "should return an instance of Command::Delete." do
        command = Castoro::Protocol.parse '["1.1","C","DELETE",{"basket":"987654321.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Command::Delete
        command.to_s.should == '["1.1","C","DELETE",{"basket":"987654321.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it "should return an instance of Command::Insert." do
        command = Castoro::Protocol.parse '["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Command::Insert
        command.to_s.should == '["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it "should return an instance of Command::Drop." do
        command = Castoro::Protocol.parse '["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Command::Drop
        command.to_s.should == '["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","C","ALIVE",{"host":"host100","status":"30","available":"1000"}]' do
      it "should return an instance of Command::Alive." do
        command = Castoro::Protocol.parse '["1.1","C","ALIVE",{"host":"host100","status":30,"available":1000}]'
        command.should be_kind_of Castoro::Protocol::Command::Alive
        command.to_s.should == '["1.1","C","ALIVE",{"host":"host100","status":30,"available":1000}]' + "\r\n"
      end
    end

    context '["1.1","C","STATUS",{}]' do
      it "should return an instance of Command::Status." do
        command = Castoro::Protocol.parse '["1.1","C","STATUS",{}]'
        command.should be_kind_of Castoro::Protocol::Command::Status
        command.to_s.should == '["1.1","C","STATUS",{}]' + "\r\n"
      end
    end

    context '["1.1","R","NOP",{}]' do
      it "should return an instance of Response::Nop." do
        command = Castoro::Protocol.parse '["1.1","R","NOP",{}]'
        command.should be_kind_of Castoro::Protocol::Response::Nop
        command.to_s.should == '["1.1","R","NOP",{}]' + "\r\n"
      end
    end

    context '["1.1","R","NOP",{"error":"Unexpected error!"}]' do
      it "should return an instance of Response::Nop." do
        command = Castoro::Protocol.parse '["1.1","R","NOP",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Nop
        command.to_s.should == '["1.1","R","NOP",{"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"basket":"123456789.1.2"}]' do
      it 'should return an instance of Response::Create .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create
        command.to_s.should == '["1.1","R","CREATE",{"basket":"123456789.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should return an instance of Response::Create .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create
        command.to_s.should == '["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Response::Create .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create
        command.to_s.should == '["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]' do
      it 'should return an instance of Response::Create::Gateway .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]'
        command.should be_kind_of Castoro::Protocol::Response::Create::Gateway
        command.to_s.should == '["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"hosts":["host101","host102","host100"],"error":"Unexpected error!"}]' do
      it 'should return an instance of Response::Create::Gateway .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"hosts":["host101","host102","host100"],"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create::Gateway
        command.to_s.should == '["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]' do
      it 'should return an instance of Response::Create::Peer .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create::Peer
        command.to_s.should == '["1.1","R","CREATE",{"basket":"123456789.1.2","host":"host101","path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2", "error":"Unexpected error!"}]' do
      it 'should return an instance of Response::Create::Peer .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2", "error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create::Peer
        command.to_s.should == '["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CREATE",{"host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2","error":"Unexpected error!"}]' do
      it 'should return an instance of Response::Create::Peer .' do
        command = Castoro::Protocol.parse '["1.1","R","CREATE",{"host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2","error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Create::Peer
        command.to_s.should == '["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Finalize' do
        command = Castoro::Protocol.parse '["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Response::Finalize
        command.to_s.should == '["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","R","FINALIZE",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Finalize .' do
        command = Castoro::Protocol.parse '["1.1","R","FINALIZE",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Finalize
        command.to_s.should == '["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","FINALIZE",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Finalize .' do
        command = Castoro::Protocol.parse '["1.1","R","FINALIZE",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Finalize
        command.to_s.should == '["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CANCEL",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Cancel' do
        command = Castoro::Protocol.parse '["1.1","R","CANCEL",{"basket":"123456789.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Response::Cancel
        command.to_s.should == '["1.1","R","CANCEL",{"basket":"123456789.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","R","CANCEL",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Cancel .' do
        command = Castoro::Protocol.parse '["1.1","R","CANCEL",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Cancel
        command.to_s.should == '["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","CANCEL",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Cancel .' do
        command = Castoro::Protocol.parse '["1.1","R","CANCEL",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Cancel
        command.to_s.should == '["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Delete' do
        command = Castoro::Protocol.parse '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]'
        command.should be_kind_of Castoro::Protocol::Response::Get
        command.to_s.should == '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]' + "\r\n"
      end
    end

    context '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Delete .' do
        command = Castoro::Protocol.parse '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Get
        command.to_s.should == '["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","GET",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Delete .' do
        command = Castoro::Protocol.parse '["1.1","R","GET",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Get
        command.to_s.should == '["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","DELETE",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Delete' do
        command = Castoro::Protocol.parse '["1.1","R","DELETE",{"basket":"123456789.1.2"}]'
        command.should be_kind_of Castoro::Protocol::Response::Delete
        command.to_s.should == '["1.1","R","DELETE",{"basket":"123456789.1.2"}]' + "\r\n"
      end
    end

    context '["1.1","R","DELETE",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Delete .' do
        command = Castoro::Protocol.parse '["1.1","R","DELETE",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Delete
        command.to_s.should == '["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","DELETE",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Delete .' do
        command = Castoro::Protocol.parse '["1.1","R","DELETE",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Delete
        command.to_s.should == '["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","INSERT",{}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Insert' do
        command = Castoro::Protocol.parse '["1.1","R","INSERT",{}]'
        command.should be_kind_of Castoro::Protocol::Response::Insert
        command.to_s.should == '["1.1","R","INSERT",{}]' + "\r\n"
      end
    end

    context '["1.1","R","INSERT",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Insert .' do
        command = Castoro::Protocol.parse '["1.1","R","INSERT",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Insert
        command.to_s.should == '["1.1","R","INSERT",{"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","DROP",{}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Drop' do
        command = Castoro::Protocol.parse '["1.1","R","DROP",{}]'
        command.should be_kind_of Castoro::Protocol::Response::Drop
        command.to_s.should == '["1.1","R","DROP",{}]' + "\r\n"
      end
    end

    context '["1.1","R","DROP",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Drop .' do
        command = Castoro::Protocol.parse '["1.1","R","DROP",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Drop
        command.to_s.should == '["1.1","R","DROP",{"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","ALIVE",{}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Alive' do
        command = Castoro::Protocol.parse '["1.1","R","ALIVE",{}]'
        command.should be_kind_of Castoro::Protocol::Response::Alive
        command.to_s.should == '["1.1","R","ALIVE",{}]' + "\r\n"
      end
    end

    context '["1.1","R","ALIVE",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Alive .' do
        command = Castoro::Protocol.parse '["1.1","R","ALIVE",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Alive
        command.to_s.should == '["1.1","R","ALIVE",{"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","STATUS",{}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Status' do
        command = Castoro::Protocol.parse '["1.1","R","STATUS",{}]'
        command.should be_kind_of Castoro::Protocol::Response::Status
        command.to_s.should == '["1.1","R","STATUS",{"status":{}}]' + "\r\n"
      end
    end

    context '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5}}]' do
      it 'should be able to create an instance of Castoro::Protocol::Response::Status' do
        command = Castoro::Protocol.parse '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5}}]'
        command.should be_kind_of Castoro::Protocol::Response::Status
        command.to_s.should == '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5}}]' + "\r\n"
      end
    end

    context '["1.1","R","STATUS",{"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Status .' do
        command = Castoro::Protocol.parse '["1.1","R","STATUS",{"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Status
        command.to_s.should == '["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n"
      end
    end

    context '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5},"error":"Unexpected error!"}]' do
      it 'should return an instance of Castoro::Protocol::Response::Status .' do
        command = Castoro::Protocol.parse '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5},"error":"Unexpected error!"}]'
        command.should be_kind_of Castoro::Protocol::Response::Status
        command.to_s.should == '["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n"
      end
    end
  end

  context 'when first of parsed arguments is not String' do
    it "should raise Castoro::Protocol Error ." do
      Proc.new{
        Castoro::Protocol.parse '[1.1,"C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '[{"num":1.1},"C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '[[1.1],"C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
    end
  end

  context 'when second of parsed arguments is not String' do
    it "should raise Castoro::Protocol Error ." do
      Proc.new{
        Castoro::Protocol.parse '["1.1",123,"CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1.1",{"C":123},"CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1.1",["C"],"CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
    end
  end

  context 'when third of parsed arguments is not String' do
    it "should raise Castoro::Protocol Error ." do
      Proc.new{
        Castoro::Protocol.parse '["1.1","C",123,{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1.1","C",{"CREATE":123},{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1.1","C",["CREATE"],{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
      }.should raise_error(Castoro::ProtocolError)
    end
  end

  context 'when fourth of parsed arguments is not Hash' do
    it "should raise Castoro::Protocol Error ." do
      Proc.new{
        Castoro::Protocol.parse '["1.1","C","CREATE",123]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1.1","C","CREATE",["basket":"987654321.1.2","hints":{"length":"12345","class":1}]]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1.1","C","CREATE",""basket":"987654321.1.2","hints":{"length":"12345","class":1}"]'
      }.should raise_error(Castoro::ProtocolError)
    end
  end

  context 'when the version number is invalid 'do
    it "should raise Castoro::Protocol Error ." do
      Proc.new{
        Castoro::Protocol.parse '["1.0","C","CREATE",["basket":"987654321.1.2","hints":{"length":"12345","class":1}]]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["2.1","C","CREATE",["basket":"987654321.1.2","hints":{"length":"12345","class":1}]]'
      }.should raise_error(Castoro::ProtocolError)
      Proc.new{
        Castoro::Protocol.parse '["1","C","CREATE",["basket":"987654321.1.2","hints":{"length":"12345","class":1}]]'
      }.should raise_error(Castoro::ProtocolError)
    end
  end

end



