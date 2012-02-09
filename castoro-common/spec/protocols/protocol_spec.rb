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

describe Castoro::Protocol do
  it 'should not be able to parse, because argument set \'[nil,nil,nil,nil]\'.' do
    Proc.new {
      Castoro::Protocol.parse '[nil,nil,nil,nil]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error - Illegal JSON format.")
  end

  it 'should not be able to parse, because argument set 123.' do
    Proc.new {
      Castoro::Protocol.parse 123
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error.")
  end

  it 'should not be able to parse, because argument set \'["1.1","C","NOP"]\'.' do
    Proc.new {
      Castoro::Protocol.parse '["1.1","C","NOP"]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error.")
  end

  it 'should not be able to parse, because argument set \'[1.1,"C","NOP",{}]\'.' do
    Proc.new {
      Castoro::Protocol.parse '[1.1,"C","NOP",{}]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error.")
  end

  it 'should not be able to parse, because argument set \'["1.1",1,"NOP",{}]\'.' do
    Proc.new {
      Castoro::Protocol.parse '["1.1",1,"NOP",{}]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error.")
  end

  it 'should not be able to parse, because argument set \'["1.1","C",1,{}]\'.' do
    Proc.new {
      Castoro::Protocol.parse '["1.1","C",1,{}]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error.")
  end

  it 'should not be able to parse, because argument set \'["1.1","C","NOP",[]]\'.' do
    Proc.new {
      Castoro::Protocol.parse '["1.1","C","NOP",[]]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error.")
  end

  it 'should not be able to parse, because argument set \'["1.0","C","NOP",{}]\'.' do
    Proc.new {
      Castoro::Protocol.parse '["1.0","C","NOP",{}]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error - unsupported version.")
  end

  it 'should not be able to parse, because argument set \'["1.1","D","NOP",{}]\'.' do
    Proc.new {
      Castoro::Protocol.parse '["1.1","D","NOP",{}]'
    }.should raise_error(Castoro::ProtocolError, "Protocol parse error - unsupported direction.")
  end

  context "when parsed" do
    it "should be rvaluated as another instance of the same." do
      nop1 = Castoro::Protocol.parse '["1.1","C","NOP",{}]'
      nop2 = Castoro::Protocol.parse '["1.1","C","NOP",{}]'
      (nop1== nop2).should be_true
    end

    context 'when argument set ["1.1","C","NOP",{}]' do
      it 'should be able to create an instance of "NOP" command.' do
        command = Castoro::Protocol::parse'["1.1","C","NOP",{}]'
        command.should be_kind_of(Castoro::Protocol::Command::Nop)
        command.to_s.should be_synonymas_with('["1.1","C","NOP",{}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]' do
      it 'should ba able to create an instance of "CREATE" command.' do
        command = Castoro::Protocol.parse '["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":"12345","class":1}}]'
        command.should be_kind_of(Castoro::Protocol::Command::Create)
        command.to_s.should be_synonymas_with('["1.1","C","CREATE",{"basket":"987654321.1.2","hints":{"length":12345,"class":"1"}}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it 'should be able to create an instance of "FINALIZE" command.' do
        command = Castoro::Protocol.parse '["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Finalize)
        command.to_s.should be_synonymas_with('["1.1","C","FINALIZE",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it 'should be able to create an instance of "CANCEL" command.' do
        command = Castoro::Protocol.parse '["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Cancel)
        command.to_s.should be_synonymas_with('["1.1","C","CANCEL",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","GET",{"basket":"987654321.1.2"}]' do
      it 'should be able to create an instance of "GET" command.' do
        command = Castoro::Protocol.parse '["1.1","C","GET",{"basket":"987654321.1.2"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Get)
        command.to_s.should be_synonymas_with('["1.1","C","GET",{"basket":"987654321.1.2"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","GET",{"basket":"987654321.1.2","island":"ebc45678"}]' do
      it 'should be able to create an instance of "GET" command.' do
        command = Castoro::Protocol.parse '["1.1","C","GET",{"basket":"987654321.1.2","island":"ebc45678"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Get)
        command.to_s.should be_synonymas_with('["1.1","C","GET",{"basket":"987654321.1.2","island":"ebc45678"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","DELETE",{"basket":"987654321.1.2"}]' do
      it 'should be able to create an instance of "DELETE" command.' do
        command = Castoro::Protocol.parse '["1.1","C","DELETE",{"basket":"987654321.1.2"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Delete)
        command.to_s.should be_synonymas_with('["1.1","C","DELETE",{"basket":"987654321.1.2"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it'should be able to create an instance of "INSERT"command.' do
        command = Castoro::Protocol.parse '["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Insert)
        command.to_s.should be_synonymas_with('["1.1","C","INSERT",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' do
      it 'should be able to create an instance of "DROP" command.' do
        command = Castoro::Protocol.parse '["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Drop)
        command.to_s.should be_synonymas_with('["1.1","C","DROP",{"basket":"987654321.1.2","host":"host100","path":"/expdsk/1/baskets/a/0/987/654/321.1.2"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","ALIVE",{"host":"host100","status":"30","available":"1000"}]' do
      it 'should be able to create an instance of "ALIVE" command.' do
        command = Castoro::Protocol.parse '["1.1","C","ALIVE",{"host":"host100","status":30,"available":1000}]'
        command.should be_kind_of(Castoro::Protocol::Command::Alive)
        command.to_s.should be_synonymas_with('["1.1","C","ALIVE",{"host":"host100","status":30,"available":1000}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","ISLAND",{"island":"ebcdef10","storables":"30","capacity":"1000"}]' do
      it 'should be able to create an instance of "ISLAND" command.' do
        command = Castoro::Protocol.parse '["1.1","C","ISLAND",{"island":"ebcdef10","storables":30,"capacity":1000}]'
        command.should be_kind_of(Castoro::Protocol::Command::Island)
        command.to_s.should be_synonymas_with('["1.1","C","ISLAND",{"island":"ebcdef10","storables":30,"capacity":1000}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","STATUS",{}]' do
      it 'should be able to create an instance of "STATUS" command.' do
        command = Castoro::Protocol.parse '["1.1","C","STATUS",{}]'
        command.should be_kind_of(Castoro::Protocol::Command::Status)
        command.to_s.should be_synonymas_with('["1.1","C","STATUS",{}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","DUMP",{}]' do
      it 'should be able to create an instance of "DUMP" command.' do
        command = Castoro::Protocol.parse '["1.1","C","DUMP",{}]'
        command.should be_kind_of(Castoro::Protocol::Command::Dump)
        command.to_s.should be_synonymas_with('["1.1","C","DUMP",{}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end
    
    context 'when argument set ["1.1","C","MKDIR",{"mode":0,"user":"user100","group":"group100","source":"source100"}]' do
      it 'should be able to create an instance of "MKDIR" command.' do
        command = Castoro::Protocol.parse '["1.1","C","MKDIR",{"mode":0,"user":"user100","group":"group100","source":"source100"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Mkdir)
        command.to_s.should be_synonymas_with('["1.1","C","MKDIR",{"mode":"0","user":"user100","group":"group100","source":"source100"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","C","MV",{"mode":0,"user":"user100","group":"group100","source":"source100","dest":"dest100"}]' do
      it 'should be able to create an instance of "MV" command.' do
        command = Castoro::Protocol.parse '["1.1","C","MV",{"mode":0,"user":"user100","group":"group100","source":"source100","dest":"dest100"}]'
        command.should be_kind_of(Castoro::Protocol::Command::Mv)
        command.to_s.should be_synonymas_with('["1.1","C","MV",{"mode":"0","user":"user100","group":"group100","source":"source100","dest":"dest100"}]' + "\r\n")
        command.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","NOP",{}]' do
      it 'should be able to create an instance of "NOP" response.' do
        response = Castoro::Protocol.parse '["1.1","R","NOP",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Nop)
        response.to_s.should be_synonymas_with('["1.1","R","NOP",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","NOP",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "NOP" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","NOP",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Nop)
        response.to_s.should be_synonymas_with('["1.1","R","NOP",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of "CREATE" response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":"123456789.1.2"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CREATE" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CREATE" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]' do
      it 'should be able to create an instance of "CREATE" gateway response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"]}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"],"island":"ebcdef10"}]' do
      it 'should be able to create an instance of "CREATE" gateway response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"],"island":"ebcdef10"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":"123456789.1.2","hosts":["host101","host102","host100"],"island":"ebcdef10"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"hosts":["host101","host102","host100"],"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CREATE" gateway error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"hosts":["host101","host102","host100"],"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":null,"hosts":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]' do
      it 'should be able to create an instance of "CREATE" peer response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":"123456789.1.2","host":"host101","path":"/expdsk/1/baskets/w/0/123/456/789.1.2"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2", "error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CREATE" peer error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"basket":"123456789.1.2", "host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2", "error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CREATE",{"host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2","error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CREATE" peer error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CREATE",{"host":"host101", "path":"/expdsk/1/baskets/w/0/123/456/789.1.2","error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Create::Peer)
        response.to_s.should be_synonymas_with('["1.1","R","CREATE",{"basket":null,"host":null,"path":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of "FINALIZE" response' do
        response = Castoro::Protocol.parse '["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Finalize)
        response.to_s.should be_synonymas_with('["1.1","R","FINALIZE",{"basket":"123456789.1.2"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","FINALIZE",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "FINALIZE" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","FINALIZE",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Finalize)
        response.to_s.should be_synonymas_with('["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","FINALIZE",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "FINALIZE" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","FINALIZE",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Finalize)
        response.to_s.should be_synonymas_with('["1.1","R","FINALIZE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CANCEL",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of "CANCEL" response.' do
        response = Castoro::Protocol.parse '["1.1","R","CANCEL",{"basket":"123456789.1.2"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Cancel)
        response.to_s.should be_synonymas_with('["1.1","R","CANCEL",{"basket":"123456789.1.2"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CANCEL",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CANCEL" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CANCEL",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Cancel)
        response.to_s.should be_synonymas_with('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","CANCEL",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "CANCEL" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","CANCEL",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Cancel)
        response.to_s.should be_synonymas_with('["1.1","R","CANCEL",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]' do
      it 'should be able to create an instance of "GET" response' do
        response = Castoro::Protocol.parse '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]'
        response.should be_kind_of(Castoro::Protocol::Response::Get)
        response.to_s.should be_synonymas_with('["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"}}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"island":"ebc45678"}]' do
      it 'should be able to create an instance of "GET" response' do
        response = Castoro::Protocol.parse '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"island":"ebc45678"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Get)
        response.to_s.should be_synonymas_with('["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"island":"ebc45678"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "GET" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","GET",{"basket":"123456789.1.2","paths":{"host1":"path1/2/3/4","host2":"path5/6/7/8"},"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Get)
        response.to_s.should be_synonymas_with('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","GET",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "GET" error response .' do
        response = Castoro::Protocol.parse '["1.1","R","GET",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Get)
        response.to_s.should be_synonymas_with('["1.1","R","GET",{"basket":null,"paths":{},"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","DELETE",{"basket":"123456789.1.2"}]' do
      it 'should be able to create an instance of "DLELTE" response' do
        response = Castoro::Protocol.parse '["1.1","R","DELETE",{"basket":"123456789.1.2"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Delete)
        response.to_s.should be_synonymas_with('["1.1","R","DELETE",{"basket":"123456789.1.2"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","DELETE",{"basket":"123456789.1.2","error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "DELETE" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","DELETE",{"basket":"123456789.1.2","error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Delete)
        response.to_s.should be_synonymas_with('["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","DELETE",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "DELETE" response.' do
        response= Castoro::Protocol.parse '["1.1","R","DELETE",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Delete)
        response.to_s.should be_synonymas_with('["1.1","R","DELETE",{"basket":null,"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","INSERT",{}]' do
      it 'should be able to create an instance of "INSERT" response' do
        response= Castoro::Protocol.parse '["1.1","R","INSERT",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Insert)
        response.to_s.should be_synonymas_with('["1.1","R","INSERT",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","INSERT",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "INSERT" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","INSERT",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Insert)
        response.to_s.should be_synonymas_with('["1.1","R","INSERT",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","DROP",{}]' do
      it 'should be able to create an instance of "DROP" response' do
        response = Castoro::Protocol.parse '["1.1","R","DROP",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Drop)
        response.to_s.should be_synonymas_with('["1.1","R","DROP",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","DROP",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "DROP" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","DROP",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Drop)
        response.to_s.should be_synonymas_with('["1.1","R","DROP",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","ALIVE",{}]' do
      it 'should be able to create an instance of "ALIVE" response' do
        response = Castoro::Protocol.parse '["1.1","R","ALIVE",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Alive)
        response.to_s.should be_synonymas_with('["1.1","R","ALIVE",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","ALIVE",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "ALIVE" error response.' do
        response= Castoro::Protocol.parse '["1.1","R","ALIVE",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Alive)
        response.to_s.should be_synonymas_with('["1.1","R","ALIVE",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","ISLAND",{}]' do
      it 'should be able to create an instance of "ISLAND" response' do
        response = Castoro::Protocol.parse '["1.1","R","ISLAND",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Island)
        response.to_s.should be_synonymas_with('["1.1","R","ISLAND",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","ISLAND",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "ISLAND" error response.' do
        response= Castoro::Protocol.parse '["1.1","R","ISLAND",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Island)
        response.to_s.should be_synonymas_with('["1.1","R","ISLAND",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","STATUS",{}]' do
      it 'should be able to create an instance of "STATUS" response' do
        response = Castoro::Protocol.parse '["1.1","R","STATUS",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Status)
        response.to_s.should be_synonymas_with('["1.1","R","STATUS",{"status":{}}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5}}]' do
      it 'should be able to create an instance of "STATUS" response' do
        response = Castoro::Protocol.parse '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5}}]'
        response.should be_kind_of(Castoro::Protocol::Response::Status)
        response.to_s.should be_synonymas_with('["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5}}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","STATUS",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "STATUS" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","STATUS",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Status)
        response.to_s.should be_synonymas_with('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5},"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "STATUS" error response.' do
        response = Castoro::Protocol.parse '["1.1","R","STATUS",{"status":{"CACHE_REQUEST":10,"CACHE_HITS":5},"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Status)
        response.to_s.should be_synonymas_with('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","MKDIR",{}]' do
      it 'should be able to create an instance of "MKDIR" response' do
        response = Castoro::Protocol.parse '["1.1","R","MKDIR",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Mkdir)
        response.to_s.should be_synonymas_with('["1.1","R","MKDIR",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","MKDIR",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "MKDIR" error response.' do
        response= Castoro::Protocol.parse '["1.1","R","MKDIR",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Mkdir)
        response.to_s.should be_synonymas_with('["1.1","R","MKDIR",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","MV",{}]' do
      it 'should be able to create an instance of "MV" response' do
        response = Castoro::Protocol.parse '["1.1","R","MV",{}]'
        response.should be_kind_of(Castoro::Protocol::Response::Mv)
        response.to_s.should be_synonymas_with('["1.1","R","MV",{}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
      end
    end

    context 'when argument set ["1.1","R","MV",{"error":"Unexpected error!"}]' do
      it 'should be able to create an instance of "MV" error response.' do
        response= Castoro::Protocol.parse '["1.1","R","MV",{"error":"Unexpected error!"}]'
        response.should be_kind_of(Castoro::Protocol::Response::Mv)
        response.to_s.should be_synonymas_with('["1.1","R","MV",{"error":"Unexpected error!"}]' + "\r\n")
        response.to_s.should match(/.+\r\n/)
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
     end
   end
  end
end
