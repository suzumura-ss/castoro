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

describe Castoro::Client do
  before do
    @key   = Castoro::BasketKey.new(1, 2, 3)
    @hints = { "class" => "hints" }
    @peers = [ "peer" ]
    @create_command = Castoro::Protocol::Command::Create.new @key, @hints
    @delete_command = Castoro::Protocol::Command::Delete.new @key

    @key_1 = Castoro::BasketKey.new(1, 1, 1)
    @key_2 = Castoro::BasketKey.new(1, 1, 2)
    @key_3 = Castoro::BasketKey.new(1, 1, 3)
    @get_command_1  = Castoro::Protocol::Command::Get.new @key_1
    @get_command_2  = Castoro::Protocol::Command::Get.new @key_2
    @get_command_3  = Castoro::Protocol::Command::Get.new @key_3

    @alive = false
    @sid   = 0
    @sender_mock = mock(Castoro::Client::TimeslideSender)
    @sender_mock.stub!(:start).and_return  { @alive = true; nil }
    @sender_mock.stub!(:stop).and_return   { @alive = false; nil }
    @sender_mock.stub!(:alive?).and_return { !!@alive }
    @sender_mock.stub!(:sid).and_return    { @sid }
    @sender_mock.stub!(:send)
    Castoro::Client::TimeslideSender.stub!(:new).and_return(@sender_mock)

    options = {
      "my_host" => "127.0.0.1",
      "logger"  => Logger.new(nil),
    }
    @client = Castoro::Client.new options
    class << @client
      public :send, :create_internal, :open_peer_connection
    end
    @client.open

    @sender_mock.stub!(:send).with(@get_command_1).and_return {
      Castoro::Protocol::Response::Get.new nil, @key_1, { "peer"=>"paths" }
    }
    @sender_mock.stub!(:send).with(@get_command_2).and_return {
      Castoro::Protocol::Response.new nil
    }
    @sender_mock.stub!(:send).with(@get_command_3).and_return {
      Castoro::Protocol::Response::Get.new "error", @key_3, { "peer"=>"paths" }
    }
  end

  it "The argument should not be able to omit of #get." do
    Proc.new {
      @client.get
    }.should raise_error(ArgumentError)
  end

  it "The argument should not be able to omit of #create." do
    Proc.new {
      @client.create
    }.should raise_error(ArgumentError)
  end

  it "#create shall not be block argument omissible." do
    Proc.new {
      @client.create @key
    }.should raise_error(Castoro::ClientError)
  end

  it "The argument should not be able to omit of #create_direct." do
    Proc.new {
      @client.create_direct
    }.should raise_error(ArgumentError)
  end

  it "#create shall not be block argument omissible." do
    Proc.new {
      @client.create_direct @peers, @key
    }.should raise_error(Castoro::ClientError)
  end

  it "The argument should not be able to omit of #delete." do
    Proc.new {
      @client.delete
    }.should raise_error(ArgumentError)
  end

  context "When closed." do
    before do
      @client.close
    end

    it "should not be able to #get" do
      Proc.new {
        @client.get(@key)
      }.should raise_error(Castoro::ClientError)
    end

    it "should not be able to #create" do
      Proc.new {
        @client.create(@key, @hints) { |h, p| }
      }.should raise_error(Castoro::ClientError)
    end

    it "should not be able to #create_direct" do
      Proc.new {
        @client.create_direct(@peers, @key, @hints) { |h, p| }
      }.should raise_error(Castoro::ClientError)
    end

    it "should not be able to #delete" do
      Proc.new {
        @client.delete(@key)
      }.should raise_error(Castoro::ClientError)
    end

    after do
      #
    end
  end

  context "when get" do
    context "key was givewn Castoro::BasketKey." do
      it "should return peer paths." do
        @client.get(@key_1).should == { "peer" => "paths" }
      end
    end

    context "Response not intended." do
      it "should raise Castoro::ClientError." do
        Proc.new {
          @client.get(@key_2)
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "get command failed" do
      it "should raise Castoro::ClientError." do
        Proc.new {
          @client.get(@key_3)
        }.should raise_error(Castoro::ClientError)
      end
    end
  end
  
  context "when create" do

    context "key was given Castoro::BasketKey instance." do
      it "TimeSlideSender#send and #create_internal should be called once." do
        @sender_mock.should_receive(:send).exactly(1).and_return {
          Castoro::Protocol::Response::Create::Gateway.new nil, @key, {}
        }
        @client.should_receive(:create_internal).exactly(1)
        @client.create(@key, @hints){}
      end
    end

    context "the Response not intended." do
      it "should raise Castoro::ClientError with TimeslideSender#send should be called once." do
        @sender_mock.should_receive(:send).exactly(1).and_return {
          Castoro::Protocol::Response::Create.new nil, @key
        }
        Proc.new {
          @client.create(@key, @hints){}
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "gateway connection failed." do
      it "should raise Castoro::ClientError with #send should be called once." do
        @sender_mock.should_receive(:send).exactly(1).and_return {
          Castoro::Protocol::Response::Create::Gateway.new "error", @key, {}
        }
        Proc.new {
          @client.create(@key, @hints){}
        }.should raise_error(Castoro::ClientError)
      end
    end
  end

  context "when create_direct" do

    context "key was given Castoro::BasketKey instance." do
      it "create_internal should be called once." do
        @client.should_receive(:create_internal).exactly(1)
        @client.create_direct(@peers, @key, @hints) {}
      end
    end
  end

  context "when delete" do
    before do
      @client.stub!(:get).and_return({"peer" => "/foo/bar/baz"})

      #TCP sender mock.
      @sender = mock Castoro::Sender::TCP
      @sender.stub!(:start).with(0.05)
      @sender.stub!(:stop)
      @sender.stub!(:alive?).and_return(true)
      @sender.stub!(:send).with(Castoro::Protocol::Command::Nop.new, 0.05).and_return {
        Castoro::Protocol::Response::Nop.new nil
      }
      @sender.stub!(:send).with(@delete_command, 5.00).and_return {
        Castoro::Protocol::Response::Delete.new nil, @key
      }
      Castoro::Sender::TCP.stub!(:new).with(@client.instance_variable_get(:@logger), "peer", 30111).and_return @sender
    end

    context "key was given Castoro::BasketKey instance." do
      it "should return nil with #get and #open_peer_connection should be called once." do
        @client.should_receive(:get).exactly(1)
        @client.should_receive(:open_peer_connection).exactly(1)
        @client.delete(@key)
      end
    end

    context "delete command timeout." do
      it "should raise Castoro::ClientNothingPeerError with get should be called once." do
        @sender.stub!(:send).with(@delete_command, 5.00)
        @client.should_receive(:get).exactly(1)
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end

    context "Response not intended." do
      it "should raise Castoro::ClientNothingPeerError with get should be called once." do
        @sender.stub!(:send).with(@delete_command, 5.00).and_return {
          Castoro::Protocol::Response.new(nil)
        }
        @client.should_receive(:get).exactly(1)
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end

    context "delete command failed." do
      it "should raise Castoro::ClientNothingPeerError with get should be called once." do
        @sender.stub!(:send).with(@delete_command, 5.00).and_return {
          Castoro::Protocol::Response::Delete.new("error", @key)
        }
        @client.should_receive(:get).exactly(1)
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end
  end
  
  after do
    @client.close rescue nil
    @client = nil
  end
end
