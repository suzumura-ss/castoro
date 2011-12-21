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

describe Castoro::Protocol::Command do
  context "when initialized" do
    before do
      @cmd = Castoro::Protocol::Command.new
    end

    it "should be able to return error response without argument." do
      res = @cmd.error_response
      res.should be_kind_of(Castoro::Protocol::Response)
      res.error?.should be_true
      res.error.should == {}
    end

    it "should be able to return error response with argument." do
      res = @cmd.error_response "Unexpected error!"
      res.should be_kind_of(Castoro::Protocol::Response)
      res.error?.should be_true
      res.error.should == "Unexpected error!"
    end
  end

  context 'when not be parsed' do
    it 'should not be able to create an instance, because "Protocol parse error - unsupported opecode.".' do
      Proc.new {
        Castoro::Protocol::Command.parse nil, nil
      }.should raise_error(RuntimeError, "Protocol parse error - unsupported opecode.")
    end
  end

  context 'when parsed, argument for opecode set "NOP"' do
    it "should be able to create an instance of nop command." do
      Castoro::Protocol::Command.parse("NOP", nil).should be_kind_of(Castoro::Protocol::Command::Nop)
    end
  end

  context 'when parsed, argument for opecode set "CREATE"' do
    it "should be able to create an instance of create command." do
      Castoro::Protocol::Command.parse("CREATE", { "basket" => "1.2.3", "hints" => { "length" => "12345", "class" => "1" } }).should be_kind_of(Castoro::Protocol::Command::Create)
    end
  end

  context 'when parsed, argument for opecode set "FINALIZE"' do
    it "should be able to create an instance of finalize command." do
      Castoro::Protocol::Command.parse("FINALIZE", { "basket" => "1.2.3", "host" => "host100", "path" => "/path/1.2.3" }).should be_kind_of(Castoro::Protocol::Command::Finalize)
    end
  end

  context 'when parsed, argument for opecode set "CANCEL"' do
    it "should be able to create an instance of cancel command." do
      Castoro::Protocol::Command.parse("CANCEL", { "basket" => "1.2.3", "host" => "host100", "path" => "/path/1.2.3"}).should be_kind_of(Castoro::Protocol::Command::Cancel)
    end
  end

  context 'when parsed, argument for opecode set "GET"' do
    it "should be able to create an instance of get command." do
      Castoro::Protocol::Command.parse("GET", { "basket" => "1.2.3" }).should be_kind_of(Castoro::Protocol::Command::Get)
    end
  end

  context 'when parsed, argument for opecode set "GET"' do
    it "should be able to create an instance of get command with island." do
      Castoro::Protocol::Command.parse("GET", { "basket" => "1.2.3" , "island" => "abc45678"}).should be_kind_of(Castoro::Protocol::Command::Get)
    end
  end

  context 'when parsed, argument for opecode set "DELETE"' do
    it "should be able to create an instance of delete command." do
      Castoro::Protocol::Command.parse("DELETE", { "basket" => "1.2.3" }).should be_kind_of(Castoro::Protocol::Command::Delete)
    end
  end

  context 'when parsed, argument for opecode set "INSERT"' do
    it "should be able to create an instance of insert command." do
      Castoro::Protocol::Command.parse("INSERT", { "basket" => "1.2.3", "host" => "host100", "path" => "/path/1.2.3"} ).should be_kind_of(Castoro::Protocol::Command::Insert)
    end
  end

  context 'when parsed, argument for opecode set "DROP"' do
    it "should be able to create an instance of drop command." do
      Castoro::Protocol::Command.parse("DROP", { "basket" => "1.2.3", "host" => "host100", "path" => "/path/1.2.3" }).should be_kind_of(Castoro::Protocol::Command::Drop)
    end
  end

  context 'when parsed, argument for opecode set "ALIVE"' do
    it "should be able to create an instance of alive command." do
      Castoro::Protocol::Command.parse("ALIVE", { "host" => "host100", "status" => 30, "available" => 123456 }).should be_kind_of(Castoro::Protocol::Command::Alive)
    end
  end

  context 'when parsed, argument for opecode set "ISLAND"' do
    it "should be able to create an instance of island command." do
      Castoro::Protocol::Command.parse("ISLAND", { "island" => "12346abc", "storables" => 15, "capacity" => 12345689 }).should be_kind_of(Castoro::Protocol::Command::Island)
    end
  end

  context 'when parsed, argument for opecode set "STATUS"' do
    it "should be able to create an instance of status command." do
      Castoro::Protocol::Command.parse("STATUS", nil).should be_kind_of(Castoro::Protocol::Command::Status)
    end
  end

  context 'when parsed, argument for opecode set "DUMP"' do
    it "should be able to create an instance of dump command." do
      Castoro::Protocol::Command.parse("DUMP", nil).should be_kind_of(Castoro::Protocol::Command::Dump)
    end
  end

  context 'when parsed, argument for opecode set "MKDIR"' do
    it "should be able to create an instance of mkdir command." do
      Castoro::Protocol::Command.parse("MKDIR", { "mode" => 1, "user" => "user100", "group" => "group100", "source" => "source100" }).should be_kind_of(Castoro::Protocol::Command::Mkdir)
    end
  end

  context 'when parsed, argument for opecode set "MV"' do
    it "should be able to create an instance of mv command." do
      Castoro::Protocol::Command.parse("MV", { "mode" => 1, "user" => "user100", "group" => "group100", "source" => "source100", "dest" => "dest100" }).should be_kind_of(Castoro::Protocol::Command::Mv)
    end
  end
end
