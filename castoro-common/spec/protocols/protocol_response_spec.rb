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

describe Castoro::Protocol::Response do
  context 'when initialize, argument for error set nil' do
    it 'should be able to create an instance of response.' do
      Castoro::Protocol::Response.new(nil).should be_kind_of(Castoro::Protocol::Response)
    end

    context 'when initialized' do
      before do
        @response = Castoro::Protocol::Response.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R",null,{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!"' do
    it 'should be able to create an instance of response.' do
      Castoro::Protocol::Response.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response)
    end

    context 'when initialized' do
      before do
        @response = Castoro::Protocol::Response.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R",null,{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end

  context 'when not be parsed' do
    it 'should not be able to create an instance, because "Protocol parse error - unsupported opecode.".' do
      Proc.new {
        Castoro::Protocol::Response.parse "UNKNOWN", nil
      }.should(raise_error RuntimeError, "Protocol parse error - unsupported opecode.")
    end
  end

  context 'when parsed, argument for opecode set "NOP"' do
    it "should be able to create an instance of nop response." do
      Castoro::Protocol::Response.parse("NOP", {"error" => nil}).should be_kind_of(Castoro::Protocol::Response::Nop)
    end
  end

  context 'when parsed, argument for opecode set "CREATE"' do
    it "should be able to create an instance of create response." do
      Castoro::Protocol::Response.parse("CREATE", {"error" => nil, "basket" => "1.2.3"}).should be_kind_of(Castoro::Protocol::Response::Create)
    end
  end

  context 'when parsed, argument for opecode set "CREATE" with argument for hosts of operand set' do
    it "should be able to create an instance of create gateway response." do
      Castoro::Protocol::Response.parse("CREATE", {"error" => nil, "basket" => "1.2.3", "hosts" => ["peer100", "peer200", "peer300"]}).should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
    end
  end

  context 'when operand set to error, basket, hosts and island.' do
    it "should be able to create an instance of create gateway response." do
      Castoro::Protocol::Response.parse("CREATE", {"error" => nil, "basket" => "1.2.3", "hosts" => ["peer100", "peer200", "peer300"], "island" => "abcdef10"}).should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
    end
  end

  context 'when parsed, argument for opecode set "CREATE" with argument for host of operand set "host100" and argument for path of operand set "path100"' do
    it "should be able to create an instance of create peer response." do
      Castoro::Protocol::Response.parse("CREATE", {"error" => nil, "basket" => "1.2.3", "host" => "peer100", "path" => "/path/1.2.3" }).should be_kind_of(Castoro::Protocol::Response::Create::Peer)
    end
  end

  context 'when parsed, argument for opecode set "FINALIZE"' do
    it "should be able to create an instance of finalize response." do
      Castoro::Protocol::Response.parse("FINALIZE", {"error" => nil, "basket" => "1.2.3", "host" => "peer100", "path" => "/path/1.2.3" }).should be_kind_of(Castoro::Protocol::Response::Finalize)
    end
  end

  context 'when parsed, argument for opecode set "CANCEL"' do
    it "should be able to create an instance of cancel response." do
      Castoro::Protocol::Response.parse("CANCEL", {"error" => nil, "basket" => "1.2.3"}).should be_kind_of(Castoro::Protocol::Response::Cancel)
    end
  end

  context 'when parsed, argument for opecode set "GET" with argument for hosts of operand set ""' do
    it "should be able to create an instance of get response." do
      Castoro::Protocol::Response.parse("GET", {"error" => nil, "basket" => "1.2.3", "paths" => { "peer100" => "/path/1.2.3", "peer200" => "/path/1.2.3" }}).should be_kind_of(Castoro::Protocol::Response::Get)
    end
  end

  context 'when parsed, argument for opecode set "GET" with argument for hosts of operand set "" and set island' do
    it "should be able to create an instance of get response." do
      Castoro::Protocol::Response.parse("GET", {"error" => nil, "basket" => "1.2.3", "paths" => { "peer100" => "/path/1.2.3", "peer200" => "/path/1.2.3" }, "island" => "abc45678"}).should be_kind_of(Castoro::Protocol::Response::Get)
    end
  end

  context 'when parsed, argument for opecode set "DELETE"' do
    it "should be able to create an instance of delete response." do
      Castoro::Protocol::Response.parse("DELETE", {"error" => nil, "basket" => "1.2.3"}).should be_kind_of(Castoro::Protocol::Response::Delete)
    end
  end

  context 'when parsed, argument for opecode set "INSERT"' do
    it "should be able to create an instance of insert response." do
      Castoro::Protocol::Response.parse("INSERT", {"error" => nil}).should be_kind_of(Castoro::Protocol::Response::Insert)
    end
  end

  context 'when parsed, argument for opecode set "DROP"' do
    it "should be able to create an instance of drop response." do
      Castoro::Protocol::Response.parse("DROP", {"error" => nil}).should be_kind_of(Castoro::Protocol::Response::Drop)
    end
  end

  context 'when parsed, argument for opecode set "ALIVE"' do
    it "should be able to create an instance of alive response." do
      Castoro::Protocol::Response.parse("ALIVE", {"error" => nil}).should be_kind_of(Castoro::Protocol::Response::Alive)
    end
  end

  context 'when parsed, argument for opecode set "ISLAND"' do
    it "should be able to create an instance of island response." do
      Castoro::Protocol::Response.parse("ISLAND", {"error" => nil}).should be_kind_of(Castoro::Protocol::Response::Island)
    end
  end

  context 'when parsed, argument for opecode set "STATUS"' do
    it "should be able to create an instance of status response." do
      Castoro::Protocol::Response.parse("STATUS", {"error" => nil, "condition" => "fine"}).should be_kind_of(Castoro::Protocol::Response::Status)
    end
  end

  context 'when parsed, argument for opecode set "MKDIR"' do
    it "should be able to create an instance of mkdir response." do
      Castoro::Protocol::Response.parse("MKDIR", {"error" => nil, "mode" => 1, "user" => "user100", "group" => "group100", "source" => "source100" }).should be_kind_of(Castoro::Protocol::Response::Mkdir)
    end
  end

  context 'when parsed, argument for opecode set "MV"' do
    it "should be able to create an instance of mv response." do
      Castoro::Protocol::Response.parse("MV", {"error" => nil, "mode" => 1, "user" => "user100", "group" => "group100", "source" => "source100", "dest" => "dest100" }).should be_kind_of(Castoro::Protocol::Response::Mv)
    end
  end

  context 'when parsed, argument for opecode set Nil' do
    it "should be able to create an instance of response." do
      Castoro::Protocol::Response.parse(nil, {"error" => nil}).should be_kind_of(Castoro::Protocol::Response)
    end
  end

end
