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
  before(:all) do
    @times_of_open_close = 100

    @test_configs = {
      "my_host" => "localhost",
      "my_ports" => [30000],
      "expire" => 1.0,
      "request_interval" => 0.10,
      "gateways" => [ "localhost:30152" ],
      "peer_port" => 30151,
      "tcp_connect_expire" => 0.01,
      "tcp_connect_retry" => 0,
      "tcp_request_expire" => 1.00,
    }
  end

  before do
    @logger = mock Logger
    @logger.stub!(:info)
    Logger.stub!(:new).and_return(@logger)

    Castoro::Client::DEFAULT_SETTINGS["my_host"] = "127.0.0.1"

    @sender_mock = mock(Castoro::Client::TimeslideSender)
  end

  it "#initialize should be able to be done by omitting argument." do
    init_args = [
      @logger,
      Castoro::Client::DEFAULT_SETTINGS["my_host"],
      Castoro::Client::DEFAULT_SETTINGS["my_ports"].to_a,
      Castoro::Client::DEFAULT_SETTINGS["gateways"],
      Castoro::Client::DEFAULT_SETTINGS["expire"],
      Castoro::Client::DEFAULT_SETTINGS["request_interval"],
    ]
    Castoro::Client::TimeslideSender.should_receive(:new).with(*init_args).and_return(@sender_mock)

    @client = Castoro::Client.new
  end

  context "when constructor argument is omitted." do
    before do
      Castoro::Client::TimeslideSender.stub!(:new).and_return(@sender_mock)
      @client = Castoro::Client.new
    end

    it "should be kind of Castoro::Client instance." do
      @client.should be_kind_of Castoro::Client
    end

    it "should be respond_to open, close, opened?, closed?, create, create_direct, delete, get." do
      @client.should respond_to :open, :close, :opened?, :closed?, :create, :create_direct, :delete, :get
    end

    it "should be used default settings." do
      @client.instance_variable_get(:@peer_port).should          == Castoro::Client::DEFAULT_SETTINGS["peer_port"]
      @client.instance_variable_get(:@tcp_connect_expire).should == Castoro::Client::DEFAULT_SETTINGS["tcp_connect_expire"]
      @client.instance_variable_get(:@tcp_connect_retry).should  == Castoro::Client::DEFAULT_SETTINGS["tcp_connect_retry"]
      @client.instance_variable_get(:@tcp_request_expire).should == Castoro::Client::DEFAULT_SETTINGS["tcp_request_expire"]
    end
  end

  it "constructor argument should influence the instance variable.." do
    init_args = [
      @logger,
      @test_configs["my_host"],
      @test_configs["my_ports"].to_a,
      @test_configs["gateways"],
      @test_configs["expire"],
      @test_configs["request_interval"],
    ]
    Castoro::Client::TimeslideSender.should_receive(:new).with(*init_args).and_return(@sender_mock)

    @client = Castoro::Client.new(@test_configs)

    @client.instance_variable_get(:@peer_port).should          == @test_configs["peer_port"]
    @client.instance_variable_get(:@tcp_connect_expire).should == @test_configs["tcp_connect_expire"]
    @client.instance_variable_get(:@tcp_connect_retry).should  == @test_configs["tcp_connect_retry"]
    @client.instance_variable_get(:@tcp_request_expire).should == @test_configs["tcp_request_expire"]
  end

  context "When Hash composed of 'host', 'port' set to options['gateways'] element." do
    it "TimeslideSender#new should receive with joined string." do
      conf = {
        "gateways" => [ { "host" => "127.0.0.1", "port" => 30112 } ]
      }
      
      init_args = [
        @logger,
        Castoro::Client::DEFAULT_SETTINGS["my_host"],
        Castoro::Client::DEFAULT_SETTINGS["my_ports"].to_a,
        [ "127.0.0.1:30112" ],
        Castoro::Client::DEFAULT_SETTINGS["expire"],
        Castoro::Client::DEFAULT_SETTINGS["request_interval"],
      ]
      Castoro::Client::TimeslideSender.should_receive(:new).with(*init_args).and_return(@sender_mock)

      @client = Castoro::Client.new(conf)
    end
  end

  context "When Hash composed of 'host' set to options['gateways'] element." do
    it "PORT number should applied to default number." do
      conf = {
        "gateways" => [ { "host" => "127.0.0.1" } ]
      }
      joined = "127.0.0.1:#{Castoro::Client::GATEWAY_DEFAULT_PORT}"
      
      init_args = [
        @logger,
        Castoro::Client::DEFAULT_SETTINGS["my_host"],
        Castoro::Client::DEFAULT_SETTINGS["my_ports"].to_a,
        [ joined ],
        Castoro::Client::DEFAULT_SETTINGS["expire"],
        Castoro::Client::DEFAULT_SETTINGS["request_interval"],
      ]
      Castoro::Client::TimeslideSender.should_receive(:new).with(*init_args).and_return(@sender_mock)

      @client = Castoro::Client.new(conf)
    end
  end

  context "When opened." do
    before do
      alive = false
      @sender_mock.stub!(:start ).and_return { alive = true; nil }
      @sender_mock.stub!(:stop  ).and_return { alive = false; nil }
      @sender_mock.stub!(:alive?).and_return { !!alive }

      Castoro::Client::TimeslideSender.stub!(:new).and_return(@sender_mock)
      @client = Castoro::Client.new @test_configs
      @client.open
    end

    it "should opened true" do
      @client.opened?.should be_true
    end

    it "should closed false" do
      @client.closed?.should be_false
    end

    it "shoule not be able to open" do
      Proc.new {
        @client.open
      }.should raise_error(Castoro::ClientError)
    end

    context "When closed." do
      before do
        @client.close
      end

      it "should opened false" do
        @client.opened?.should be_false
      end

      it "should closed true" do
        @client.closed?.should be_true
      end

      it "should be able to #start > #stop > #start > ..." do
        @times_of_open_close.times {
          @client.open
          @client.close
        } 
      end
    end

    after do
      @client.close rescue nil
    end
  end

  after do
    @client = nil
  end
end

