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
    @peers = [ "peer1", "peer2", "peer3"]
    @create_command = Castoro::Protocol::Command::Create.new @key, @hints
    @delete_command = Castoro::Protocol::Command::Delete.new @key

    @key_1 = Castoro::BasketKey.new(1, 1, 1)
    @key_2 = Castoro::BasketKey.new(1, 1, 2)
    @key_3 = Castoro::BasketKey.new(1, 1, 3)
    @key_4 = Castoro::BasketKey.new(1, 1, 4)
    @get_command_1 = Castoro::Protocol::Command::Get.new @key_1
    @get_command_2 = Castoro::Protocol::Command::Get.new @key_2
    @get_command_3 = Castoro::Protocol::Command::Get.new @key_3
    @get_command_4 = Castoro::Protocol::Command::Get.new @key_4, "abcdef12".to_island

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
      public :send, :create_internal
    end
    @client.open

    @sender_mock.stub!(:send).with(@get_command_1).and_return {
      Castoro::Protocol::Response::Get.new nil, @key_1, { "peer"=>"paths" }, "12345678".to_island
    }
    @sender_mock.stub!(:send).with(@get_command_2).and_return {
      Castoro::Protocol::Response.new nil
    }
    @sender_mock.stub!(:send).with(@get_command_3).and_return {
      Castoro::Protocol::Response::Get.new "error", @key_3, { "peer"=>"paths" }, "abcdef12".to_island
    }
    @sender_mock.stub!(:send).with(@get_command_4).and_return {
      Castoro::Protocol::Response::Get.new "nil", @key_4, { "peer"=>"paths" }, "abcdef12".to_island
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
      it "TimeSlideSender#send, #connect and #create_internal should be called once." do
        @sender_mock.should_receive(:send).once.with(@create_command).and_return {
          Castoro::Protocol::Response::Create::Gateway.new nil, @key, @peers
        }
        @client.should_receive(:create_internal).once.with("connection","peer","remining_peers",@create_command, {})
        @client.should_receive(:connect).once.with(@peers).and_yield("connection","peer","remining_peers").and_return(true)
        @client.create(@key, @hints){}
      end
    end

    context "if connet peers failed" do
      it "should raise ClientNothingPeerError." do
        @sender_mock.should_receive(:send).once.with(@create_command).and_return {
          Castoro::Protocol::Response::Create::Gateway.new nil, @key, @peers
        }
        @client.should_receive(:connect).once.and_return(false)
        Proc.new {
          @client.create(@key, @hints) {}
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end

    context "the Response not intended." do
      it "should raise Castoro::ClientError with TimeslideSender#send should be called once." do
        @sender_mock.should_receive(:send).once.with(@create_command).and_return {
          Castoro::Protocol::Response::Create.new nil, @key
        }
        Proc.new {
          @client.create(@key, @hints){}
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "gateway connection failed." do
      it "should raise Castoro::ClientError with #send should be called once." do
        @sender_mock.should_receive(:send).once.with(@create_command).and_return {
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
      it "#connect and #create_internal should be called once." do
        @client.should_receive(:create_internal).once.with("connection","peer","remining_peers",@create_command, {})
        @client.should_receive(:connect).once.with(@peers).and_yield("connection","peer","remining_peers").and_return(true)
        @client.create_direct(@peers, @key, @hints) {}
      end
    end

    context "if connet peers failed" do
      it "should raise ClientNothingPeerError." do
        @client.should_receive(:connect).once.and_return(false)
        Proc.new {
          @client.create_direct(@peers, @key, @hints) {}
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end

    context "all peers can connect but raise Error" do
      it "should #connect called recursively." do
        Castoro::Sender::TCP.should_receive(:new).exactly(3).and_return(@sender)
        Proc.new {
          @client.create_direct(@peers, @key, @hints) {}
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end
  end

  context "when delete" do
    before do
      @peers_hash = {"peer1" => "foo/",  "peer2" => "bar/", "peer3" => "baz/"}
      @client.stub!(:get).and_return(@peers_hash)

      #TCP sender mock.
      @sender = mock Castoro::Sender::TCP
      @sender.stub!(:start).with(0.05)
      @sender.stub!(:closed?)
      @sender.stub!(:close)
      @sender.stub!(:stop)
      @sender.stub!(:alive?).and_return(true)
      @sender.stub!(:send).with(Castoro::Protocol::Command::Nop.new, 0.05).and_return {
        Castoro::Protocol::Response::Nop.new nil
      }
      @sender.stub!(:send).with(@delete_command, 5.00).and_return {
        Castoro::Protocol::Response::Delete.new nil, @key
      }
      Castoro::Sender::TCP.stub!(:new).and_return @sender
    end

    context "key was given Castoro::BasketKey instance." do
      it "should return nil with #get and #connect should be called once." do
        @client.should_receive(:get).once
        @client.should_receive(:connect).once.with(@peers_hash.keys).and_return(true)
        @client.delete(@key)
      end
    end

    context "if connet peers failed" do
      it "should raise ClientNothingPeerError." do
        @client.should_receive(:connect).once.and_return(false)
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientNothingPeerError)
      end
    end

    context "if delete command timeout." do
      it "should raise Castoro::ClientTimeoutError with get should be called once." do
        @sender.stub!(:send).with(@delete_command, 5.00)
        @client.should_receive(:get).once
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientTimeoutError)
      end
    end

    context "if response not intended." do
      it "should raise Castoro::ClientError with get should be called once." do
        @sender.stub!(:send).with(@delete_command, 5.00).and_return {
          Castoro::Protocol::Response.new(nil)
        }
        @client.should_receive(:get).once
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "if delete command failed." do
      it "should raise Castoro::ClientError with get should be called once." do
        @sender.stub!(:send).with(@delete_command, 5.00).and_return {
          Castoro::Protocol::Response::Delete.new("error", @key)
        }
        @client.should_receive(:get).once
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "if peer1 and peer2 can't connect and peer3 raise Castoro::ClientError" do
      it "should raise Castoro::ClientError" do
        Castoro::Sender::TCP.stub!(:new).with(@client.instance_variable_get(:@logger), "peer1", 30111)
        Castoro::Sender::TCP.stub!(:new).with(@client.instance_variable_get(:@logger), "peer2", 30111)

        @sender.stub!(:send).with(@delete_command, 5.00).and_return {
          Castoro::Protocol::Response::Delete.new("error", @key)
        }
        @client.should_receive(:get).once
        Proc.new {
          @client.delete(@key)
        }.should raise_error(Castoro::ClientError)
      end
    end

    after do
      @client.close rescue nil
      @client = nil
    end
  end

  describe "#get" do
    context "given island argument" do
      it "should return peer paths and island." do
        Proc.new {
          @client.get(@key_4, { :island => "abcdef12"}).should == { "peer" => "paths", "island" =>  "abcdef12"}
        }
      end
    end

    context "given island argument is nil" do
      it "should return peer paths and island." do
        Proc.new {
          @client.get(@key_4, nil).should == { "peer" => "paths", "island" =>  "abcdef12"}
        }
      end

      it "should return peer paths and island." do
        Proc.new {
          @client.get(@key_4, { :island => nil}).should == { "peer" => "paths", "island" =>  "abcdef12"}
        }
      end
    end
  end

  describe "#get_with_island" do
    context "given island argumet" do
      it "should return peer paths and island." do
        Proc.new {
#          @client.get_with_island(@key_4, { :island => "abcdef12"}).should == { "peer" => "paths", "island" =>  "abcdef12"}
          @client.get_with_island(@key_4, "abcdef12").should == { "peer" => "paths", "island" =>  "abcdef12"}
        }
      end
    end

    context "given island argumet is nil" do
      it "should return peer paths and island." do
        Proc.new {
          @client.get_with_island(@key_4, nil).should == { "peer" => "paths", "island" =>  "abcdef12"}
        }
      end
    end
  end

  after do
    @key            = nil
    @hints          = nil
    @peers          = nil
    @create_command = nil
    @delete_command = nil
    @key_1          = nil
    @key_2          = nil
    @key_3          = nil
    @key_4          = nil
    @get_command_1  = nil
    @get_command_2  = nil
    @get_command_3  = nil
    @get_command_4  = nil
    @alive          = nil
    @sid            = nil
    @sender_mock    = nil
    @client         = nil
  end
end
