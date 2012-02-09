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

describe Castoro::Protocol::Command::Status do
  context 'when initialize' do
    it "should be able to create an instance of status command." do
      Castoro::Protocol::Command::Status.new.should be_kind_of(Castoro::Protocol::Command::Status)
    end

    context "when initialized" do
      before do
        @command = Castoro::Protocol::Command::Status.new
      end

      it "should be able to use #to_s." do
        JSON.parse(@command.to_s).should ==
          JSON.parse('["1.1","C","STATUS",{}]' + "\r\n")
      end

      it "should be able to return error_response without argument." do
        error_res = @command.error_response
        error_res.should be_kind_of(Castoro::Protocol::Response::Status)
        error_res.error?.should be_true
        JSON.parse(error_res.to_s).should ==
          JSON.parse('["1.1","R","STATUS",{"status":{},"error":{}}]' + "\r\n")
      end

      context "when set error response" do
        it "should be able to return error_response with argument." do
          error_res = @command.error_response("Unexpected error!")
          error_res.should be_kind_of(Castoro::Protocol::Response::Status)
          error_res.error?.should be_true
          JSON.parse(error_res.to_s).should ==
            JSON.parse('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
        end
      end
    end
  end
end

describe Castoro::Protocol::Response::Status do
  it 'should not be able to create an instance, because raise RuntimeError "status should be Hash."' do
    Proc.new {
      Castoro::Protocol::Response::Status.new nil, ""
    }.should raise_error(RuntimeError, "status should be a Hash.")
  end

  context 'when initialize, argument for error set nil, argument for status set {"condition" => "fine"}' do
    it 'should be able to create an instance of status response.' do
      Castoro::Protocol::Response::Status.new(nil, {"condition" => "fine"}).should be_kind_of(Castoro::Protocol::Response::Status)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Status.new nil, {"condition" => "fine"}
      end

      it 'should be #error? false.' do
        @response.error?.should be_false
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","STATUS",{"status":{"condition":"fine"}}]' + "\r\n")
      end

      it 'should be able to use #method_missing.' do
        @response.key?("condition").should be_true
      end
    end
  end

  context 'when initialize, argument for error set "Unexpected error!", argument for status set {"condition" => "fine"}' do
    it 'should be able to create an instance of status error response.' do
      Castoro::Protocol::Response::Status.new("Unexpected error!", {"condition" => "fine"}).should be_kind_of(Castoro::Protocol::Response::Status)
    end

    context "when initialized" do
      before do
        @response = Castoro::Protocol::Response::Status.new("Unexpected error!", {"condition" => "fine"})
      end

      it 'should be #error? true.' do
        @response.error?.should be_true
      end

      it 'should be able to use #to_s.' do
        JSON.parse(@response.to_s).should ==
          JSON.parse('["1.1","R","STATUS",{"status":{},"error":"Unexpected error!"}]' + "\r\n")
      end

      it 'should not be able to use #method_missing.' do
        Proc.new{
          @response.key?("condition")
        }.should raise_error(NoMethodError)
      end
    end
  end
end
