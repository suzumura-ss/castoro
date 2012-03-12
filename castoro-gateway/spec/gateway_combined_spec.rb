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

require 'stringio'
require 'drb/drb'

# mock for client
class ClientMock
  def initialize my_port, destination, dest_port
    @destination = destination
    @dest_port   = dest_port
    @my_port     = my_port
  end

  def send header, data
    receiver = UDPSocket.open
    receiver.bind "0.0.0.0", @my_port

    sender = UDPSocket.new
    sender.send "#{header}#{data}", 0, @destination, @dest_port

    if(res = IO::select([receiver], nil, nil, 1))
      sock  = res[0][0]
      res   = sock.recv(1256)
      lines = res.split "\r\n"
      res   = Castoro::Protocol.parse lines[1]
    end

    receiver.close
    receiver = nil

    res
  end
end


describe Castoro::Gateway do
  before(:all) do
    @conf = Castoro::Gateway::Configuration.new({
      "workers" => 5,
      "peer_multicast_addr" => "239.192.1.2",
      "peer_multicast_device" => "eth0",
      "cache" => {
        "cache_size" => 1000000
      },
      "gateway_console_port" => 30150,
      "gateway_unicast_port" => 30151,
      "gateway_multicast_port" => 30149,
      "gateway_watchdog_port" => 30153,
      "peer_multicast_port" => 30152,
    })

    # console
    DRb.start_service
    @console = DRbObject.new_with_uri "druby://127.0.0.1:#{@conf["gateway_console_port"]}"
  end

  before do
    @logger = Logger.new(ENV['DEBUG'] ? STDOUT : nil)

    @localhost     = "127.0.0.1"
    @client_port   = 30003
    @key1          = "1.1.1"
    @key2          = "2.1.1"
    @peer100       = "peer100"
    @peer200       = "peer200"
    @peer300       = "peer300"
    @peer400       = "peer400"
    @content1_path = "/expdsk/1/baskets/a/0/000/000/1.1.1"
    @content2_path = "/expdsk/1/baskets/a/0/000/000/2.1.1"
    @udp_header    = Castoro::Protocol::UDPHeader.new(@localhost, @client_port)

    # initialize dependency classes.
    Castoro::Gateway.dependency_classes_init

    @g = Castoro::Gateway.new(@conf, @logger)
    @g.start
    
    # mock for client.
    @client = ClientMock.new(@client_port, @localhost, @conf["gateway_unicast_port"])

    # mock for peer sender.
    @peer = Castoro::Sender::UDP.new nil
    @peer.start
  end

  it "should be response an instance of Castoro::Protocol::Response::Nop." do
    res = @client.send @udp_header, Castoro::Protocol::Command::Nop.new
    res.should be_kind_of(Castoro::Protocol::Response::Nop)
  end
  
  it "should bo able to get status" do
    res = @console.status
    res[:CACHE_EXPIRE].should            == Castoro::Gateway::Configuration.new()["cache"]["watchdog_limit"]
    res[:CACHE_REQUESTS].should          == 0
    res[:CACHE_HITS].should              == 0
    res[:CACHE_COUNT_CLEAR].should       == 0
    res[:CACHE_ALLOCATE_PAGES].should    == @conf["cache"]["cache_size"] / Castoro::Cache::PAGE_SIZE
    res[:CACHE_FREE_PAGES].should        == @conf["cache"]["cache_size"] / Castoro::Cache::PAGE_SIZE
    res[:CACHE_ACTIVE_PAGES].should      == 0
    res[:CACHE_HAVE_STATUS_PEERS].should == 0
    res[:CACHE_ACTIVE_PEERS].should      == 0
    res[:CACHE_READABLE_PEERS].should    == 0
  end
  
  it 'should be cache is empty.' do
    io = StringIO.new
    @console.dump io
    io.string.should == "\n"
  end
  
  it "should not respond to an empty packet." do
    res = @client.send @udp_header, ""
    res.should be_nil
  end
  
  it "should not respond to an unexpeced command." do
    mkdir = Castoro::Protocol::Command::Mkdir.new 1, 2, 3, 4
    res = @client.send @udp_header, mkdir
    res.should be_nil
  end

  context "when not received watchdog packets" do
    before do
      insert = Castoro::Protocol::Command::Insert.new(@key1, @peer100, @content1_path)
      @peer.send @udp_header, insert, @localhost, @conf["gateway_multicast_port"]
    end
  
    it "should not respond to the query cache, because not received watchdog packet." do
      get = Castoro::Protocol::Command::Get.new(@key1)
      res = @client.send @udp_header, get
      res.should be_nil
    end
  
    it "should be request sent to peers." do
      # mock for peer of multicast receiver.
      multicast_receiver = Castoro::Receiver::UDP.new(@logger, @conf["peer_multicast_port"]) { |h, d, p, i|
        Castoro::Sender::UDP.new(nil) { |s|
          get_res = Castoro::Protocol::Response::Get.new(false, d.basket, { @peer100 => "response from multicast receiver" })
          s.send @udp_header, get_res, h.ip, h.port
        }
      }
      multicast_receiver.start
      get = Castoro::Protocol::Command::Get.new(@key1)
      res = @client.send @udp_header, get
      multicast_receiver.stop

      res.should be_kind_of(Castoro::Protocol::Response::Get)
      res.basket.to_s.should == @key1
      res.paths.should       == { @peer100 => "response from multicast receiver" }
    end
  end
  
  context "when received watchdog packets" do
    before do
      first_packet_sended = nil
      @watchdog = Thread.fork {
        begin
          alive = Castoro::Protocol::Command::Alive.new(@peer100, Castoro::Cache::Peer::ACTIVE, 100*1000)
          @peer.send @udp_header, alive, @localhost, @conf["gateway_watchdog_port"]
  
          alive = Castoro::Protocol::Command::Alive.new(@peer200, Castoro::Cache::Peer::ACTIVE, 1000*1000)
          @peer.send @udp_header, alive, @localhost, @conf["gateway_watchdog_port"]
  
          alive = Castoro::Protocol::Command::Alive.new(@peer300, Castoro::Cache::Peer::READONLY, 0)
          @peer.send @udp_header, alive, @localhost, @conf["gateway_watchdog_port"]
  
          alive = Castoro::Protocol::Command::Alive.new(@peer400, Castoro::Cache::Peer::MAINTENANCE, 1000)
          @peer.send @udp_header, alive, @localhost, @conf["gateway_watchdog_port"]
  
          first_packet_sended = true
        end until Thread.current[:dying]
      }
      until first_packet_sended; end
    end
      
    it "should be change the status." do
      sleep 1.0
      res = @console.status
      res[:CACHE_HAVE_STATUS_PEERS].should == 4
      res[:CACHE_ACTIVE_PEERS].should      == 2
      res[:CACHE_READABLE_PEERS].should    == 3
    end
  
    context "when 2 peers be ACTIVE" do
      it "should be response 2 available peers." do
        create = Castoro::Protocol::Command::Create.new(@key1, {"class" => "hints", "length" => 100*1000 })
        res = @client.send @udp_header, create
        res.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
        res.basket.to_s.should == @key1
        res.hosts.sort.should  == [ @peer100, @peer200 ]
      end
      
      context "when available peer finding" do
        it "should be response available peer." do
          create = Castoro::Protocol::Command::Create.new(@key1, {"class" => "hints", "length" => 1000*1000 })
          res = @client.send @udp_header, create
          res.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
          res.basket.to_s.should == @key1
          res.hosts.should       == [ @peer200 ]
        end
      end
      
      context "when available peers not finding" do
        it "should return error response." do
          create = Castoro::Protocol::Command::Create.new(@key1, {"class" => "hints", "length" => 10*1000*1000 })
          res = @client.send @udp_header, create
          res.should be_kind_of(Castoro::Protocol::Response::Create::Gateway)
          res.error?.should be_true
        end
      end
      
      context "when the basket is inserted" do
        before do
          insert = Castoro::Protocol::Command::Insert.new(@key1, @peer100, @content1_path)
          @peer.send @udp_header, insert, @localhost, @conf["gateway_multicast_port"]
      
          sleep 1.0
        end
      
        it "should be change status." do
          res = @console.status
          res[:CACHE_ALLOCATE_PAGES].should == @conf["cache"]["cache_size"] / Castoro::Cache::PAGE_SIZE
          res[:CACHE_FREE_PAGES].should     == @conf["cache"]["cache_size"] / Castoro::Cache::PAGE_SIZE - 1
          res[:CACHE_ACTIVE_PAGES].should   == 1
        end
  
        it 'should be the basket is inserted into the cache.' do
          io = StringIO.new
          @console.dump io
          io.string.should == "  peer100: 1.1.1\n\n"
        end
  
        context "when the basket was added" do
          before do
            insert = Castoro::Protocol::Command::Insert.new(@key1, @peer200, @content1_path)
            @peer.send @udp_header, insert, @localhost, @conf["gateway_multicast_port"]
  
            sleep 1.0
          end
  
          it 'should be the basket is added into the cache.' do
            io = StringIO.new
            @console.dump io
            io.string.should == "  peer100: 1.1.1\n  peer200: 1.1.1\n\n"
          end
  
          context "when the query cache" do 
            it "should be response 2 paths." do
              sleep 0.01
              get = Castoro::Protocol::Command::Get.new(@key1)
              res = @client.send @udp_header, get
              res.should be_kind_of(Castoro::Protocol::Response::Get)
              res.basket.to_s.should == @key1
              res.paths.should       == { @peer100 => @content1_path, @peer200 => @content1_path }
            end
          
            it "should be change status." do
              sleep 0.01
              get = Castoro::Protocol::Command::Get.new(@key1)
              @client.send @udp_header, get
  
              res = @console.status
              res[:CACHE_REQUESTS].should    == 1
              res[:CACHE_HITS].should        == 1
              res[:CACHE_COUNT_CLEAR].should == 1000
            end
  
            context "when the query cache misses" do 
              before do
                sleep 0.01
                get = Castoro::Protocol::Command::Get.new(@key1)
                @client.send @udp_header, get
              end
  
              it "should be no response." do
                sleep 0.01
                get = Castoro::Protocol::Command::Get.new(@key2)
                res = @client.send @udp_header, get
                res.should be_nil
              end
              
              it "should be request sent to peers." do
                # mock for peer of multicast receiver.
                multicast_receiver = Castoro::Receiver::UDP.new(@logger, @conf["peer_multicast_port"]) { |h, d, p, i|
                  multicast_sender = Castoro::Sender::UDP.new nil
                  multicast_sender.start
              
                  get_res = Castoro::Protocol::Response::Get.new(false, d.basket, { @peer100 => "response from multicast receiver" })
                  multicast_sender.send @udp_header, get_res, h.ip, h.port
                }
                multicast_receiver.start
              
                get = Castoro::Protocol::Command::Get.new(@key2)
                res = @client.send @udp_header, get
                res.should be_kind_of(Castoro::Protocol::Response::Get)
                res.basket.to_s.should == @key2
                res.paths.should       == { @peer100 => "response from multicast receiver" }
              
                multicast_receiver.stop
              end
  
              it "should be change status." do
                sleep 0.01
                get = Castoro::Protocol::Command::Get.new(@key2)
                @client.send @udp_header, get
  
                sleep 2.0
                res = @console.status
                res[:CACHE_REQUESTS].should    == 2
                res[:CACHE_HITS].should        == 1
                res[:CACHE_COUNT_CLEAR].should == 500
              end
  
              context "when drop the basket" do
                before do
                  drop = Castoro::Protocol::Command::Drop.new(@key1, @peer200, @content1_path)
                  @peer.send @udp_header, drop, @localhost, @conf["gateway_multicast_port"]
                  sleep 2.0
                end
                
                it "should be response 1 path." do
                  sleep 0.01
                  get = Castoro::Protocol::Command::Get.new(@key1)
                  res = @client.send @udp_header, get
                  res.should be_kind_of(Castoro::Protocol::Response::Get)
                  res.basket.to_s.should == @key1
                  res.paths.should       == { @peer100 => @content1_path }
                end
  
                it "should be only 1 basket in the cache." do
                  io = StringIO.new
                  @console.dump io
                  io.string.should == "  peer100: 1.1.1\n\n"
                end
               
                context "when the cache is emptied" do
                  before do 
                    drop = Castoro::Protocol::Command::Drop.new(@key1, @peer100, @content1_path)
                    @peer.send @udp_header, drop, @localhost, @conf["gateway_multicast_port"]
                    sleep 1.0
                  end
  
                  it "should be dump result is empty." do
                    io = StringIO.new
                    @console.dump io
                    io.string.should == "\n"
                  end
                end
              end
            end
          end
        end
      end
    end
  
    after do
      if @watchdog
        @watchdog[:dying] = true
        @watchdog.join
        @watchdog = nil
      end
    end
  end

  after do
    @peer.stop if @peer.alive? rescue nil
    @peer = nil
 
    @g.stop if @g.alive? rescue nil 
    @g = nil
  end

  after(:all) do
    @console = nil
    DRb.stop_service
  end
end
