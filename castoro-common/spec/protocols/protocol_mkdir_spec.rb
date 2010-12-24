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

describe Castoro::Protocol::Command::Mkdir do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for mode."' do
    Proc.new {
      Castoro::Protocol::Command::Mkdir.new nil, "user100", "group100", "source100"
    }.should raise_error(RuntimeError, "Nil cannot be set for mode.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for user.".' do
    Proc.new {
      Castoro::Protocol::Command::Mkdir.new 1, nil, "group100", "source100"
    }.should raise_error(RuntimeError, "Nil cannot be set for user.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for group.".' do
    Proc.new {
      Castoro::Protocol::Command::Mkdir.new 1, "user100", nil, "source100"
    }.should raise_error(RuntimeError, "Nil cannot be set for group.")
  end

  it "should not be able to create an instance, because raise RuntimeError because of lack of source." do
    Proc.new {
      Castoro::Protocol::Command::Mkdir.new 1, "user100", "group100", nil
    }.should raise_error(RuntimeError, "Nil cannot be set for source.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "mode should set the Numeric or octal number character."' do
    Proc.new {
      Castoro::Protocol::Command::Mkdir.new "8", "user100", "group100", "source100"
    }.should raise_error(RuntimeError, "mode should set the Numeric or octal number character.")
  end

  context 'when initialize, argument for mode set "7"' do
    it "should be able to get :mode is 7." do
      command = Castoro::Protocol::Command::Mkdir.new "7", "user100", "group100", "source100"
      command.mode.should == 7
    end
  end

  context 'when initailize, argument for mode set 1, argument for user set "user100", argument for group set "group100", argument for source set "source100"' do
    it "should be able to an instance of mkdir command." do
      Castoro::Protocol::Command::Mkdir.new(1, "user100", "group100", "source100").should be_kind_of(Castoro::Protocol::Command::Mkdir)
    end

    context 'when initialized' do
      before do
        @command = Castoro::Protocol::Command::Mkdir.new 1, "user100", "group100", "source100"
      end

      it "should be able to get :mode." do
        @command.mode.should == 1
      end

      it "should be able to get :user." do
        @command.user.should == "user100"
      end

      it "should be able to get :group." do
        @command.group.should == "group100"
      end

      it "should be able to get :source." do
        @command.source.should == "source100"
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","MKDIR",{"mode":"1","user":"user100","group":"group100","source":"source100"}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Mkdir)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","MKDIR",{"error":{}}]' + "\r\n")
      end

      context "when set error response" do
        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of(Castoro::Protocol::Response::Mkdir)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","MKDIR",{"error":"Unexpected error!"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Mkdir do
  context 'when initialize, argument for error set nil' do
    it 'should be able to create an instance of mkdir response.' do
      Castoro::Protocol::Response::Mkdir.new(nil).should be_kind_of(Castoro::Protocol::Response::Mkdir)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Mkdir.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","MKDIR",{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!"' do
    it 'should be able to create an instance of mkdir error response.' do
      Castoro::Protocol::Response::Mkdir.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response::Mkdir)
    end

    context "when initailized" do
      before do
        @response = Castoro::Protocol::Response::Mkdir.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","MKDIR",{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
