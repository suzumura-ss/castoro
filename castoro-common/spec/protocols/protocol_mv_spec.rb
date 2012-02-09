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

describe Castoro::Protocol::Command::Mv do
  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for mode.".' do
    Proc.new {
      Castoro::Protocol::Command::Mv.new nil, "user100", "group100", "source100", "dest100"
    }.should raise_error(RuntimeError, "Nil cannot be set for mode.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for user."' do
    Proc.new {
      Castoro::Protocol::Command::Mv.new 1, nil, "group100", "source100", "dest100"
    }.should raise_error(RuntimeError, "Nil cannot be set for user.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "Nil cannot be set for group.".' do
    Proc.new {
      Castoro::Protocol::Command::Mv.new 1, "user100", nil, "source100", "dest100"
    }.should raise_error(RuntimeError, "Nil cannot be set for group.")
  end

  it "should not be able to create an instance, because raise RuntimeError because of lack of source." do
    Proc.new {
      Castoro::Protocol::Command::Mv.new 1, "user100", "group100", nil, "dest100"
    }.should raise_error(RuntimeError, "Nil cannot be set for source.")
  end

  it "should not be able to create an instance, because raise RuntimeError because of lack of dest." do
    Proc.new {
      Castoro::Protocol::Command::Mv.new 1, "user100", "group100", "source100", nil
    }.should raise_error(RuntimeError, "Nil cannot be set for dest.")
  end

  it 'should not be able to create an instance, because raise RuntimeError "mode should set the Numeric or octal number character."' do
    Proc.new {
      Castoro::Protocol::Command::Mv.new "8", "user100", "group100", "source100", "dest100"
    }.should raise_error(RuntimeError, "mode should set the Numeric or octal number character.")
  end

  context 'when initialize, argument for mode set "7"' do
    it "should be able to get :mode is 7." do
      command = Castoro::Protocol::Command::Mv.new "7", "user100", "group100", "source100", "dest100"
      command.mode.should == 7
    end
  end

  context 'when initialize, argument for mode set 1, argument for user set "user100", argument for group set "group100", argument for source set "source100", argument for dest set "dest100")' do
    it "should be able to create an instance of mv command." do
      Castoro::Protocol::Command::Mv.new(1, "user100", "group100", "source100", "dest100").should be_kind_of(Castoro::Protocol::Command::Mv)
    end

    context "when initialized" do
      before do
        @command = Castoro::Protocol::Command::Mv.new 1, "user100", "group100", "source100", "dest100"
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

      it "should be able to get :dest." do
        @command.dest.should == "dest100"
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","MV",{"mode":"1","user":"user100","group":"group100","source":"source100","dest":"dest100"}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Mv)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","MV",{"error":{}}]' + "\r\n")
      end

      context "when set error response" do
        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of(Castoro::Protocol::Response::Mv)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","MV",{"error":"Unexpected error!"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Mv do
  context 'when initialize, argument for error set ' do
    it 'should be able to create an instance of mv response.' do
      Castoro::Protocol::Response::Mv.new(nil).should be_kind_of(Castoro::Protocol::Response::Mv)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Mv.new nil
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","MV",{}]' + "\r\n")
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!"' do
    it 'should be able to create an instance of mv error response.' do
      Castoro::Protocol::Response::Mv.new("Unexpected error!").should be_kind_of(Castoro::Protocol::Response::Mv)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Mv.new "Unexpected error!"
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","MV",{"error":"Unexpected error!"}]' + "\r\n")
      end
    end
  end
end
