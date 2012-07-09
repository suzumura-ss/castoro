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
require 'get_devices'

describe Castoro::Gateway do
  before do
    @logger = Logger.new nil

    # pick up devices
    devices = getDevices 
    if devices.length > 0 then
      @device_addr = devices[0][1]
    else
      @device_addr = ENV['DEVICE'] || IPSocket.getaddress(Socket.gethostname)
    end    
  end

  context "when config argument is omitted" do
    before do
      @g = Castoro::Gateway.new(Castoro::Gateway::Configuration.new({
        "gateway_comm_device_addr" => @device_addr,   
        "peer_comm_device_addr" => @device_addr }),
        @logger
       )
    end

    it "should be set default settings." do
      default_config = Castoro::Gateway::Configuration.new({
        "gateway_comm_device_addr" => @device_addr,   
        "peer_comm_device_addr" => @device_addr })

      @g.instance_variable_get(:@config).should == default_config
      @g.instance_variable_get(:@logger).should be_kind_of Logger
      @g.instance_variable_get(:@logger).level.should == default_config["loglevel"].to_i
    end

    it "should alive? false." do
      @g.alive?.should be_false
    end

    context "when start" do
      before do
        @g.start
      end

      it "should alive? true." do
        @g.alive?.should be_true
      end

      it "facade should be set Castoro::Gateway::Facade instance." do
        @g.instance_variable_get(:@facade).should be_kind_of Castoro::Gateway::Facade
      end

      it "workers should be set Castoro::Gateway::Workers instance." do
        @g.instance_variable_get(:@workers).should be_kind_of Castoro::Gateway::Workers
      end

      it "repository should be set Castoro::Gateway::Repository instance." do
        @g.instance_variable_get(:@repository).should be_kind_of Castoro::Gateway::Repository
      end

      it "console should be set Castoro::Gateway::ConsoleServer instance." do
        @g.instance_variable_get(:@console).should be_kind_of Castoro::Gateway::ConsoleServer
      end

      it "should raise already started GatewayError." do
        Proc.new {
          @g.start
        }.should raise_error Castoro::GatewayError
      end

      context "when stop" do
        before do
          @g.stop
        end

        it "should alive? false." do
          @g.alive?.should be_false
        end

        it "facade should be nil." do
          @g.instance_variable_get(:@facade).should be_nil
        end

        it "workers should be nil." do
          @g.instance_variable_get(:@workers).should be_nil
        end

        it "repository should be nil." do
          @g.instance_variable_get(:@repository).should be_nil
        end

        it "console should be nil." do
          @g.instance_variable_get(:@console).should be_nil
        end

        it "should raise already stopped GatewayError." do
          Proc.new {
            @g.stop
          }.should raise_error Castoro::GatewayError
        end

        it "should be able to start > stop > start > ..." do
          10.times {
            @g.start
            @g.stop
          }
        end
      end
    end
  end

  context "when Replace the mock classes depend Gateway" do
    before do
      # mock for Castoro::Gateway::Facade
      @facade = mock Castoro::Gateway::Facade
      @facade.stub!(:new).and_return @facade
      @facade.stub!(:start)
      @facade.stub!(:stop)
      @facade.stub!(:alive?).and_return true

      # mock for Castoro::Gateway::Workers
      @workers = mock Castoro::Gateway::Workers
      @workers.stub!(:new).and_return @workers
      @workers.stub!(:start)
      @workers.stub!(:stop)
      @workers.stub!(:alive?).and_return true

      # mock for Castoro::Gateway::Repository
      @repository = mock Castoro::Gateway::Repository
      @repository.stub!(:new).and_return @repository
      @repository.stub!(:start)
      @repository.stub!(:stop)
      @repository.stub!(:alive?).and_return true

      # mock for Castoro::Gateway::ConsoleServer
      @console = mock Castoro::Gateway::ConsoleServer
      @console.stub!(:new).and_return @console
      @console.stub!(:start)
      @console.stub!(:stop)
      @console.stub!(:alive?).and_return true

      Castoro::Gateway.class_variable_set(:@@facade_class, @facade)
      Castoro::Gateway.class_variable_set(:@@workers_class, @workers)
      Castoro::Gateway.class_variable_set(:@@repository_class, @repository)
      Castoro::Gateway.class_variable_set(:@@console_server_class, @console)
    end

    it "should be set mock." do
      Castoro::Gateway.class_variable_get(:@@facade_class).should         == @facade
      Castoro::Gateway.class_variable_get(:@@workers_class).should        == @workers
      Castoro::Gateway.class_variable_get(:@@repository_class).should     == @repository
      Castoro::Gateway.class_variable_get(:@@console_server_class).should == @console
    end

    context "when dependency classes initialized" do
      it "class variables should be reset correctly." do
        Castoro::Gateway.dependency_classes_init
        Castoro::Gateway.class_variable_get(:@@facade_class).should         == Castoro::Gateway::Facade
        Castoro::Gateway.class_variable_get(:@@workers_class).should        == Castoro::Gateway::Workers
        Castoro::Gateway.class_variable_get(:@@repository_class).should     == Castoro::Gateway::Repository
        Castoro::Gateway.class_variable_get(:@@console_server_class).should == Castoro::Gateway::ConsoleServer
      end
    end

    context "given island to configurations" do
      before do
        config = Castoro::Gateway::Configuration.new({
          "type" => "island",
          "gateway_comm_ipaddr_multicast"       => "239.192.1.2",
          "gateway_comm_device_addr"            => @device_addr,
          "island_comm_device_addr"             => @device_addr,
          "peer_comm_ipaddr_multicast"          => "239.192.1.3",
          "peer_comm_device_addr"               => "127.0.0.1",
          "gateway_console_tcpport"             => 30150,
          "gateway_comm_udpport"                => 30151,
          "gateway_learning_udpport_multicast"  => 30149,
          "gateway_watchdog_udpport_multicast"  => 30153,
          "peer_comm_udpport_multicast"         => 30152,
          "island_comm_ipaddr_multicast"        => "239.192.254.254",
        })
        @g = Castoro::Gateway.new config, @logger
      end

      it "workers should initialized and start" do
        @workers.should_receive(:new).
          with(@logger, @g.instance_variable_get(:@config)["workers"],
               @facade, @repository,
                 "239.192.1.3",
                 "127.0.0.1",
                 30152,
               "239.192.254.254".to_island).exactly(1)
        @workers.should_receive(:start)
        @g.start
      end
    end

    context "when config argument is test configs" do
      before do
        test_configs = {
          "gateway_comm_ipaddr_multicast"       => "239.192.1.2",
          "gateway_comm_device_addr"            => @device_addr,
          "peer_comm_ipaddr_multicast"          => "239.192.1.3",
          "peer_comm_device_addr"               => "127.0.0.1",
          "gateway_console_tcpport"             => 30150,
          "gateway_comm_udpport"                => 30151,
          "gateway_learning_udpport_multicast"  => 30149,
          "gateway_watchdog_udpport_multicast"  => 30153,
          "peer_comm_udpport_multicast"         => 30152,
         }
        @g = Castoro::Gateway.new test_configs, @logger
      end

      context "when start" do
        it "repository should initialized." do
          @repository.should_receive(:new)
                 .with(@logger, @g.instance_variable_get(:@config)["cache"])
                 .exactly(1)
          @g.start
        end

        it "facade should initialized and start." do
          @facade.should_receive(:new)
                 .with(@logger, @g.instance_variable_get(:@config))
                 .exactly(1)
          @facade.should_receive(:start)
          @g.start
        end

        it "workers should initialized and start." do
          @workers.should_receive(:new)
                  .with(
                    @logger, @g.instance_variable_get(:@config)["workers"],
                    @facade, @repository,
                      "239.192.1.3",
                      "127.0.0.1",
                      30152,
                    nil
                  ).exactly(1)
          @workers.should_receive(:start)
          @g.start
        end

        it "console should initialized and start." do
          @console.should_receive(:new)
                  .with(
                    @logger, @repository,
                    30150
                  ).exactly(1)
          @console.should_receive(:start)
          @g.start
        end

        context "when stop with force argument is true" do
          before do
            @g.start
          end

          it "should alive? false." do
            @g.stop true
            @g.alive?.should be_false
          end
        end
      end
    end
  end

  after do
    @g.stop if @g.alive? rescue nil
    @g = nil
  end
end
