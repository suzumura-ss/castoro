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

describe Castoro::WorkersHelper do
  before do
    # mock for Logger
    @logger = mock(Logger)
    @logger.stub!(:debug)
    @logger.stub!(:warn)

    # mock for IO
    @client = mock(IO)
    @client.stub!(:puts)

    # Define WorkersHelper included class for test.
    @included = Object.new
    class << @included
      include Castoro::WorkersHelper
      attr_accessor :logger
    end
    @included.logger = @logger
  end

  it "#send_response should do send after outputting DEBUG log." do
    res = Castoro::Protocol::Response::Nop.new(nil)

    @logger.should_receive(:debug).exactly(1)
    @client.should_receive(:puts).with(res.to_s).exactly(1)

    @included.send_response(@client, res)
  end

  it "should send illegal format command the ERROR response." do
    cmd = "foo, bar, baz, qux, quux, quuux"
    res = Castoro::Protocol::Response.new(
      "code" => "Castoro::ProtocolError",
      "message" => "Protocol parse error - Illegal JSON format."
    )

    @client.should_receive(:puts).with(res.to_s).exactly(1)

    @included.accept_command(@client, cmd) { |c|
      raise "dead code."
    }
  end

  it "should send Casotro::Response the ERROR response." do
    cmd = Castoro::Protocol::Response::Finalize.new(nil, "1.2.3").to_s
    res = Castoro::Protocol::Response.new(
      "code" => "Castoro::WorkersError",
      "message" => "unsupported packet type."
    )

    @client.should_receive(:puts).with(res.to_s).exactly(1)

    @included.accept_command(@client, cmd) { |c|
      raise "dead code."
    }
  end

  it "should send NOP command the NOP response." do
    cmd = Castoro::Protocol::Command::Nop.new.to_s
    res = Castoro::Protocol::Response::Nop.new(nil)

    @client.should_receive(:puts).with(res.to_s).exactly(1)

    @included.accept_command(@client, cmd) { |c|
      raise "dead code."
    }
  end

  it "should evaluated block the response other than NOP." do
    cmds = [
      Castoro::Protocol::Command::Get.new("1.2.3"),
      Castoro::Protocol::Command::Delete.new("1.2.3"),
      Castoro::Protocol::Command::Insert.new("1.2.3", "peer1", "/expdsk/2/baskets/0/000/000/1.2.3"),
      Castoro::Protocol::Command::Drop.new("1.2.3", "peer1", "/expdsk/2/baskets/0/000/000/1.2.3"),
    ]

    cmds.each{ |cmd|

      evaluated = false
      @included.accept_command(@client, cmd.to_s) { |c|
        evaluated = true
        cmd.to_s.should == c.to_s
      }
      evaluated.should be_true
    }
  end

  context "When the evaluation of the block fails" do
    it "should send ERROR response from raised exception." do
      cmds = [
        Castoro::Protocol::Command::Get.new("1.2.3"),
        Castoro::Protocol::Command::Delete.new("1.2.3"),
        Castoro::Protocol::Command::Insert.new("1.2.3", "peer1", "/expdsk/2/baskets/0/000/000/1.2.3"),
        Castoro::Protocol::Command::Drop.new("1.2.3", "peer1", "/expdsk/2/baskets/0/000/000/1.2.3"),
      ]

      cmds.each{ |cmd|
        res = cmd.error_response("code" => "Castoro::CastoroError", "message" => "exception in block.")
        @client.should_receive(:puts).with(res.to_s).exactly(1)

        @included.accept_command(@client, cmd.to_s) { |c|
          raise Castoro::CastoroError, "exception in block."
        }
      }
    end
  end

end

