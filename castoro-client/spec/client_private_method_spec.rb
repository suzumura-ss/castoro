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
require File.dirname(__FILE__) + '/udpmock.rb'

describe Castoro::Client do
  before do
    Castoro::Sender::UDP.stub!(:new) { SenderMock.new }
    Castoro::Receiver::UDP.stub!(:new) { |logger, port, on_received|
      ReceiverMock.new(logger, port, on_received)
    }

    options = {
      "my_host"  => "127.0.0.1",
      "logger"   => Logger.new(nil),
      "gateways" => [ "127.0.0.1", "localhost" ]
    }
    @client = Castoro::Client.new options
    class << @client
      public :send, :create_internal, :open_peer_connection
    end
    @client.open

    @key = Castoro::BasketKey.new 1, 2, 3
  end

  context "when create_internal" do
    before do
      @peer     = ["peer"]
      @command  = Castoro::Protocol::Command::Create.new @key, { "class" => "hints"}
      @finalize = Castoro::Protocol::Command::Finalize.new @key, "host", "path"
      @cancel   = Castoro::Protocol::Command::Cancel.new @key, "host", "path"

      #TCP sender mock
      @sender = mock Castoro::Sender::TCP
      @sender.stub!(:start).with(0.05)
      @sender.stub!(:stop)
      @sender.stub!(:send).with(@command, 5.00).and_return Castoro::Protocol::Response::Create::Peer.new nil, @key, "host", "path"
      @sender.stub!(:send).with(@finalize, 5.00).and_return Castoro::Protocol::Response::Finalize.new nil, @key
      @sender.stub!(:send).with(@cancel, 5.00).and_return Castoro::Protocol::Response::Cancel.new nil, @key
      @sender.stub!(:alive?).and_return(true)
      Castoro::Sender::TCP.stub!(:new).with(@client.instance_variable_get(:@logger), "peer", 30111).and_return @sender
    end

    context "create command timeout." do
      it "should raise Castoro::ClientNothingPeerError." do
        @sender.stub!(:send).with(@command, 5.00)
        Proc.new {
          @client.create_internal @peer, @command
        }.should raise_error Castoro::ClientNothingPeerError
      end
    end

    context "create command response not inteded." do
      it "should raise Castoro::ClientNothingPeerError." do
        @sender.stub!(:send).with(@command, 5.00)
               .and_return Castoro::Protocol::Response::Create::Peer.new "error", @key, "host", "path"
        Proc.new {
          @client.create_internal @peer, @command
        }.should raise_error Castoro::ClientNothingPeerError
      end
    end

    context "create command failed." do
      it "should raise Castoro::ClientNothingPeerError." do
        @sender.stub!(:send).with(@command, 5.00).and_return Castoro::Protocol::Response::Create.new nil, @key
        Proc.new {
          @client.create_internal @peer, @command
        }.should raise_error Castoro::ClientNothingPeerError
      end
    end

    context "finalize command timeout." do
      it "should raise Castoro::ClientTimeoutError with TCP sender#send should be called once." do
        @sender.stub!(:send).with(@finalize, 5.00)
        @sender.should_receive(:send).with(@finalize, 5.00).exactly(1)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientTimeoutError
      end
    end

    context "finalize Response not intended." do
      it "should raise Castoro::ClientError with TCP sender#send should be called once." do
        @sender.stub!(:send).with(@finalize, 5.00).and_return Castoro::Protocol::Response.new nil
        @sender.should_receive(:send).with(@finalize, 5.00).exactly(1)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientError
      end
    end

    context "finalize command failed." do
      it "should raise Castoro::ClientError with TCP sender#send should be called once." do
        @sender.stub!(:send).with(@finalize, 5.00).and_return Castoro::Protocol::Response::Finalize.new "error", @key
        @sender.should_receive(:send).with(@finalize, 5.00).exactly(1)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientError
      end
    end

    context "cancel command timeout." do
      it "should raise Castoro::ClientTimeoutError with TCP sender#send should be called once." do
        @sender.stub!(:send).with(@finalize, 5.00)
        @sender.stub!(:send).with(@cancel, 5.00)
        @sender.should_receive(:send).with(@cancel, 5.00).exactly(1)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientTimeoutError
      end
    end

    context "cancel Response not intended." do
      it "should raise Castoro::ClientTimeoutError with TCP sender#send should be called once." do
        @sender.stub!(:send).with(@finalize, 5.00)
        @sender.stub!(:send).with(@cancel, 5.00).and_return Castoro::Protocol::Response.new nil
        @sender.should_receive(:send).with(@cancel, 5.00).exactly(1)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientTimeoutError
      end
    end

    context "cancel command failed." do
      it "should raise Castoro::ClientTimeoutError with TCP sender#send should be called once." do
        @sender.stub!(:send).with(@finalize, 5.00)
        @sender.stub!(:send).with(@cancel, 5.00).and_return Castoro::Protocol::Response::Cancel.new "error", @key
        @sender.should_receive(:send).with(@cancel, 5.00).exactly(1)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientTimeoutError
      end
    end

    context "cancel command exception." do
      it "should raise Castoro::ClientTimeoutError with logger#error and debug should be called 2times." do
        @sender.stub!(:send).with(@finalize, 5.00)
        @sender.stub!(:send).with(@cancel, 5.00).and_return { raise TimeoutError }
        @client.instance_variable_get(:@logger).should_receive(:error).exactly(2)
        @client.instance_variable_get(:@logger).should_receive(:debug).exactly(2)
        Proc.new {
          @client.create_internal(@peer, @command) { |host, path| }
        }.should raise_error Castoro::ClientTimeoutError
      end
    end
  end

  context "when open_peer_connection" do
    before do
      @key  = Castoro::BasketKey.new(1, 2, 3)

      #TCP sender mock.
      #TCP sender to peer1
      @sender1 = mock Castoro::Sender::TCP
      @sender1.stub!(:start).with(0.05)
      @sender1.stub!(:stop)
      @sender1.stub!(:alive?).and_return(true)
      Castoro::Sender::TCP.stub!(:new).with(@client.instance_variable_get(:@logger), "peer1", 30111).and_return @sender1

      #TCP sender to peer2
      @sender2 = mock Castoro::Sender::TCP
      @sender2.stub!(:start).with(0.05)
      @sender2.stub!(:stop)
      @sender2.stub!(:alive?).and_return(true)
      Castoro::Sender::TCP.stub!(:new).with(@client.instance_variable_get(:@logger), "peer2", 30111).and_return @sender2
    end

    context "first response was error response, second response was normally response." do
      it "error responsed TCP sender#alive? should be called once." do
        peers = [ "peer2", "peer1" ]
        @sender2.stub!(:start).with(0.05).and_return {
          raise Castoro::SenderTimeoutError, "connection timeout."
        }
        @client.open_peer_connection(@key, peers, nil) { |s, p|
          s.should == @sender1
          p.should == "peer1"
        }
      end
    end

    context "second response was error response, second response was normally response." do
      it "error responsed TCP sender#alive? should be called once." do
        peers = [ "peer2", "peer1" ]
        @sender1.stub!(:start).with(0.05).and_return {
          raise Castoro::SenderTimeoutError, "connection timeout."
        }
        @client.open_peer_connection(@key, peers, nil) { |s, p|
          s.should == @sender2
          p.should == "peer2"
        }
      end
    end

    context "peer_decide_proc was not given." do
      it "TCP sender#start and send and stop should be called once." do
        @sender1.should_receive(:start).exactly(1)
        @sender1.should_receive(:stop).exactly(1)
        @client.open_peer_connection @key, ["peer1"]
      end
    end

    context "peer_decide_proc was given Proc instance." do
      it "peer_decide_proc#call should be called once" do
        peer_decide_proc = Proc.new { |sender, peer|
          sender.should == @sender1
          peer.should   == "peer1"
        }
        peer_decide_proc.should_receive(:call).with(@sender1, "peer1").exactly(1)
        @client.open_peer_connection @key, ["peer1"], peer_decide_proc
      end
    end

    context "There is no Peer that can be connected by TCP." do
      it "should raise Castoro::ClientNothingPeerError." do
        @sender1.stub!(:start).with(0.05).and_return {
          raise Castoro::SenderTimeoutError, "connection timeout."
        }
        Proc.new {
          @client.open_peer_connection @key, ["peer1"]
        }.should raise_error Castoro::ClientNothingPeerError
      end
    end
  end

  after do
    @client.close rescue nil
    @client = nil
  end
end
