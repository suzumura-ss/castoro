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
      public :send, :create_internal, :delete_internal, :connect
    end
    @client.open

    @key = Castoro::BasketKey.new 1, 2, 3

    @peer           = ["peer1"]
    @remining_peers = ["peer2", "peer3"]
    @create         = Castoro::Protocol::Command::Create.new @key, { "class" => "hints"}
    @finalize       = Castoro::Protocol::Command::Finalize.new @key, "host", "path"
    @get            = Castoro::Protocol::Command::Get.new @key
    @cancel         = Castoro::Protocol::Command::Cancel.new @key, "host", "path"

    #TCP sender mock
    alive = false
    @sender = mock Castoro::Sender::TCP
    @sender.stub!(:start).with(0.05).and_return { alive = true }
    @sender.stub!(:stop).and_return { alive = false }
    @sender.stub!(:alive?).and_return(alive)
    Castoro::Sender::TCP.stub!(:new).and_return @sender
  end

  context "when create_internal" do
    context "is accepted normally." do
      it "should return true." do
        @sender.should_not_receive(:stop)
        @sender.should_receive(:send).with(@create, 5.00).once.and_return {
          Castoro::Protocol::Response::Create::Peer.new nil, @key, "host", "path"
        }
        @sender.should_receive(:send).with(@finalize, 5.00).once.and_return{
          Castoro::Protocol::Response::Finalize.new nil, @key
        }

        h, p = nil, nil
        @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|
          h = host
          p = path
        }.should be_true
        h.should == "host"
        p.should == "path"
      end
    end

    context "create command timeout to all peers." do
      it "should retry next peers recursively and raise Castoro::ClientTimeoutError." do
        @sender.should_receive(:send).with(@create, 5.00).exactly(3)
        @sender.should_receive(:stop).exactly(3)
        Proc.new {
          @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|}
        }.should raise_error(Castoro::ClientTimeoutError)
      end
    end

    context "create command failed by Castoro::Peer::ClientAlreadyExistsError." do
      it "should not retry next peer and should raise Castoro::ClientAlreadyExistsError." do
        @sender.should_receive(:send).with(@create, 5.00).once.and_return {
          Castoro::Protocol::Response::Create.new({"code" => "Castoro::Peer::AlreadyExistsError"}, @key)
        }
        @sender.should_receive(:stop).once
        Proc.new {
          @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|}
        }.should raise_error(Castoro::ClientAlreadyExistsError)
      end
    end

    context "create command response not inteded about all peers." do
      it "should retry next peer recursively and raise Castoro::ClientError." do
        @sender.should_receive(:send).with(@create, 5.00).exactly(3).and_return {
          Castoro::Protocol::Response::Finalize.new nil, @key
        }
        @sender.should_receive(:stop).exactly(3)
        Proc.new {
          @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|}
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "create command response not inteded and remining_peers = []." do
      it "should raise Castoro::ClientError." do
        @sender.should_receive(:send).with(@create, 5.00).once.and_return {
          Castoro::Protocol::Response::Finalize.new nil, @key
        }
        @sender.should_receive(:stop).once
        Proc.new {
          @client.create_internal(@sender, @peer, [], @create){|host, path|}
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "create command failed by other errors about all peers." do
      it "should retry next peer recursively and raise Castoro::ClientError." do
        @sender.should_receive(:send).with(@create, 5.00).exactly(3).and_return {
          Castoro::Protocol::Response::Create::Peer.new("error", @key, "host", "path")
        }
        @sender.should_receive(:stop).exactly(3)
        Proc.new {
          @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|}
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "create command failed by other errors and can't connect other peers." do
      it "should raise Castoro::ClientError." do
        @sender.should_receive(:send).with(@create, 5.00).once.and_return {
          Castoro::Protocol::Response::Create::Peer.new("error", @key, "host", "path")
        }
        @sender.should_receive(:stop).once
        @client.should_receive(:connect).and_return(false)
        Proc.new {
          @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|}
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "if last peer raise ClientTimeoutError and others raise ClientError" do
      it "should raise last error (ClientTimeoutError)." do
        @sender.stub!(:send).and_return(Castoro::Protocol::Response::Delete.new(nil, @key),
                                        Castoro::Protocol::Response::Create.new("error", @key),
                                        nil)
        @sender.should_receive(:stop).exactly(3)
        Proc.new{
          @client.create_internal(@sender, @peer, @remining_peers, @create){|host, path|}
        }.should raise_error(Castoro::ClientTimeoutError)
      end
    end

    context "create command failed to first peer but succeed to next peer" do
      it "should return true." do
        @sender.should_receive(:send).with(@create, 5.00).exactly(2).and_return(
          Castoro::Protocol::Response::Create::Peer.new("error", @key, "host_error", "path_error"),
          Castoro::Protocol::Response::Create::Peer.new( nil   , @key, "host", "path")
        )
        @sender.should_receive(:stop).once
        @sender.should_receive(:send).with(@finalize, 5.00).once.and_return{
          Castoro::Protocol::Response::Finalize.new nil, @key
        }

        h, p = nil, nil
        @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|
          h = host
          p = path
        }
        h.should == "host"
        p.should == "path"
      end
    end

    context "ClientNoRetryError raised while yielding." do
      it "should raise Castoro::ClientTimeoutError without retry." do
        @sender.should_receive(:send).with(@create, 5.00).once.and_return(
          Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
        )
        @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
          Castoro::Protocol::Response::Cancel.new nil, @key
        }
        Proc.new {
          @client.create_internal(@sender, @peer, @remining_peers, @create) {raise Castoro::ClientNoRetryError}
        }.should raise_error(Castoro::ClientNoRetryError)
      end
    end

    context "some other error raised while yielding." do
      it "should retry next peer." do
        finalize = Castoro::Protocol::Command::Finalize.new(@key, "host1", "path")
        
        @sender.should_receive(:send).with(@create, 5.00).once.and_return(
          Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path"),
          Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host1", "path")
        )
        @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
          Castoro::Protocol::Response::Cancel.new nil, @key
        }
        @sender.should_receive(:send).with(finalize, 5.00).once.and_return{
          Castoro::Protocol::Response::Finalize.new nil, @key
        }

        @client.create_internal(@sender, @peer, @remining_peers, @create) {|host,path|
          raise TimeoutError if host == "host"
        }
      end
    end

    context "finalize command timeout" do
      context "and cancel command accepted correctly." do
        it "should raise Castoro::ClientTimeoutError without retry." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response::Cancel.new nil, @key
          }
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end
      end
      
      context "and cancel command failed with Castoro::Peer::PreconditionFailedError" do
        before do
          @sender.stub!(:send).with(@create, 5.00).and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.stub!(:send).with(@finalize, 5.00)
          @sender.stub!(:send).with(@cancel, 5.00).and_return {
            Castoro::Protocol::Response::Cancel.new({"code" => "Castoro::Peer::PreconditionFailedError"}, @key)
          }
        end

        it "should send get command to check contents existance." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once.and_return nil
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response::Cancel.new({"code" => "Castoro::Peer::PreconditionFailedError"}, @key)
          }
          @sender.should_receive(:send).with(@get, 5.00).once
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end

        context "becaues contents already finalized correctly." do
          it "consider create command succeeded and finish normally." do
            @sender.should_receive(:send).with(@get, 5.00).once.and_return { 
              Castoro::Protocol::Response::Get.new nil, @key, {"peer" => "path"}
            }
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          end
        end

        context "but contents not exist." do
          it "should raise Castoro::ClientTimeoutError" do
            @sender.should_receive(:send).with(@get, 5.00).once
            Proc.new {
              @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
            }.should raise_error(Castoro::ClientTimeoutError)
          end
        end
      end

      context "and cancel command failed with other error." do
        it "should finish without check contens existance." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response::Cancel.new "other_error", @key
          }
          @sender.should_not_receive(:send).with(@get, 5.00)
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end
      end
    end

    context "finalize failed" do
      context "because of Response not intended." do
        it "should raise Castoro::ClientError without retry." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once.and_return{
            Castoro::Protocol::Response::Cancel.new nil, @key
          }
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response::Cancel.new nil, @key
          }
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientError)
        end
      end

      context "because of Response have error status." do
        it "should raise Castoro::ClientError without retry." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once.and_return{
            Castoro::Protocol::Response::Finalize.new "error", @key
          }
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response::Cancel.new nil, @key
          }
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientError)
        end
      end
      context "and cancel command timeout." do
        it "should raise Castoro::ClientTimeoutError." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once
          @sender.should_receive(:send).with(@cancel, 5.00).once
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end
      end

      context "and cancel Response not intended." do
        it "should raise Castoro::ClientTimeoutError." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response.new nil
          }
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end
      end

      context "and cancel command failed becaues Response have error status." do
        it "should raise Castoro::ClientTimeoutError." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once
          @sender.should_receive(:send).with(@cancel, 5.00).once.and_return {
            Castoro::Protocol::Response::Cancel.new "error", @key
          }
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end
      end

      context "and cancel command raise some error." do
        it "should raise Castoro::ClientTimeoutError with logger#error and #debug should be called 2times." do
          @sender.should_receive(:send).with(@create, 5.00).once.and_return(
            Castoro::Protocol::Response::Create::Peer.new( nil, @key, "host", "path")
          )
          @sender.should_receive(:send).with(@finalize, 5.00).once
          @sender.should_receive(:send).with(@cancel, 5.00).and_return { raise TimeoutError }
          @client.instance_variable_get(:@logger).should_receive(:error).exactly(2)
          @client.instance_variable_get(:@logger).should_receive(:debug).exactly(2)
          Proc.new {
            @client.create_internal(@sender, @peer, @remining_peers, @create) {|host, path|}
          }.should raise_error(Castoro::ClientTimeoutError)
        end
      end
    end
  end

  context "when delete_internal" do
    context "is accepted normally." do
      it "should return instance of Protocol::Response::Delete" do
        @sender.should_receive(:send).with(@delete, 5.00).and_return {
          Castoro::Protocol::Response::Delete.new nil, @key
        }
        @sender.should_not_receive(:stop)
        @client.delete_internal @sender, @peer, @remining_peers, @delete
      end
    end

    context "if delete command timeout" do
      it "should raise ClientTimeoutError." do
        @sender.stub!(:send).and_return(nil)
        @sender.should_receive(:stop).exactly(3)
        Proc.new{
          @client.delete_internal @sender, @peer, @remining_peers, @delete
        }.should raise_error(Castoro::ClientTimeoutError)
      end
    end

    context "if response is not intended" do
      it "should raise ClientError." do
        @sender.stub!(:send).and_return(Castoro::Protocol::Response::Create.new(nil, @key))
        @sender.should_receive(:stop).exactly(3)
        Proc.new{
          @client.delete_internal @sender, @peer, @remining_peers, @delete
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "if delete command faild" do
      it "should raise ClientError." do
        @sender.stub!(:send).and_return(Castoro::Protocol::Response::Delete.new("error", @key))
        @sender.should_receive(:stop).exactly(3)
        Proc.new{
          @client.delete_internal @sender, @peer, @remining_peers, @delete
        }.should raise_error(Castoro::ClientError)
      end
    end

    context "if last peer raise ClientTimeoutError and others raise ClientError" do
      it "should raise last error (ClientTimeoutError)." do
        @sender.stub!(:send).and_return(Castoro::Protocol::Response::Create.new(nil, @key),
                                        Castoro::Protocol::Response::Delete.new("error", @key),
                                        nil)
        @sender.should_receive(:stop).exactly(3)
        Proc.new{
          @client.delete_internal @sender, @peer, @remining_peers, @delete
        }.should raise_error(Castoro::ClientTimeoutError)
      end
    end

  end

  context "when connect" do
    before do
      @key   = Castoro::BasketKey.new(1, 2, 3)
      @peers = [ "peer1", "peer2", "peer3" ]

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

    context "if first peer couldn't be connected" do
      it "should try to connect next peer." do
        @sender1.stub!(:start).with(0.05).and_return {
          raise Castoro::SenderTimeoutError, "connection timeout."
        }
        @sender2.should_receive(:stop).once
        @client.connect(@peers) { |s, p, ps|
          s.should  == @sender2
          p.should  == "peer2"
          ps.should == ["peer3"]
        }.should be_true
      end
    end

    context "if first peer could be connected" do
      it "should not try to connect next peer and return true." do
        @sender1.should_receive(:stop).once
        @client.connect(@peers) { |s, p, ps|
          s.should  == @sender1
          p.should  == "peer1"
          ps.should == ["peer2", "peer3"]
        }.should be_true
      end
    end

    context "all peers could not be connected " do
      it "should return false." do
        Castoro::Sender::TCP.stub!(:new).and_return @sender
        @sender.stub!(:start).with(0.05).and_return {
          raise Castoro::SenderTimeoutError, "connection timeout."
        }
        @client.connect(@peers).should be_false
      end
    end

    context "if peers = []" do
      it "should return false." do
        @client.connect([]).should be_false
      end
    end
  end

  after do
    @client.close rescue nil
    @client = nil

    @key            = nil
    @peer           = nil
    @remining_peers = nil
    @create         = nil
    @finalize       = nil
    @get            = nil
    @cancel         = nil
    @sender         = nil
  end
end
