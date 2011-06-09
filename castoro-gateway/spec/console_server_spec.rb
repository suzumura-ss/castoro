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

console_port = 30150

describe Castoro::Gateway::ConsoleServer do
  before do
    # the Logger
    @logger = Logger.new(nil)

    # mock for repository
    @repository = mock Castoro::Gateway::Repository
    @repository.stub!(:new).and_return @repository
    @repository.stub!(:status)
    @repository.stub!(:dump).and_return "dump result"
  end

  context "when initialized with the first argument set nil" do
    it "Logger#new(nil) should be called once." do
      Logger.should_receive(:new).with(nil).exactly(1)
      @c = Castoro::Gateway::ConsoleServer.new(nil, @repository, console_port)
    end

    after do
      @c = nil
    end
  end

  context "when initialized" do
    before do
      forker = Proc.new { |server_socket, client_socket, &block|
        block.call(client_socket)
      }
      Castoro::Gateway::ConsoleServer.class_variable_set(:@@forker, forker)
      @c = Castoro::Gateway::ConsoleServer.new(@logger, @repository, console_port)
    end

    it "@logger should be set an instance of the Logger." do
      logger = @c.instance_variable_get(:@logger)
      logger.should be_kind_of(Logger)
      logger.should == @logger
    end

    it "should be able to start > stop > start ..." do
      100.times {
        @c.start
        @c.stop
      }
    end

    it "#alive? should be false." do
      @c.alive?.should be_false
    end

    it "should be set instance variables correctly from arguments." do
      @c.instance_variable_get(:@logger).should     == @logger
      @c.instance_variable_get(:@repository).should == @repository
      @c.instance_variable_get(:@port).should       == console_port
    end

    it "#stop should raise server error." do
      Proc.new {
        @c.stop
      }.should raise_error(Castoro::ServerError, "tcp server already stopped.")
    end

    context "when start" do
      it "#alive? should be true." do
        @c.start
        @c.alive?.should be_true
      end

      it "TCPServer should be initialized." do
        TCPServer.should_receive(:new).with(@c.instance_variable_get(:@host), @c.instance_variable_get(:@port)).exactly(1)
        @c.start
      end

      it "TCPServer should be set an instance variable @tcp_server." do
        @c.start
        @c.instance_variable_get(:@tcp_server).should be_kind_of(TCPServer)
      end

      it "@thread should be set forked thread." do
        @c.start
        @c.instance_variable_get(:@thread).should be_kind_of(Thread)
      end

      it "#accept_loop should be called once" do
        @c.should_receive(:accept_loop).exactly(1)
        @c.start
      end

      it "should return self." do
        @c.start.should == @c
      end

      it "#start should raise ServerError." do
        @c.start
        Proc.new {
          @c.start
        }.should raise_error(Castoro::ServerError, "tcp server already started.")
      end

      context "when receive NOP command" do
        before do 
          @c.start
        end

        it "should be response Castoro::Protocol::Response::Nop instance." do
          cmd = Castoro::Protocol::Command::Nop.new
          Castoro::Sender::TCP.start(@logger, "127.0.0.1", 30150, 2.0) { |s|
            s.send(cmd, 10.0)
          }.should be_kind_of(Castoro::Protocol::Response::Nop)
        end
      end

      context "when received STATUS command" do
        before do 
          @c.start
        end

        it "should be response Castoro::Protocol::Response::Status instance." do
          cmd = Castoro::Protocol::Command::Status.new
          @repository.should_receive(:status).exactly(1)
          Castoro::Sender::TCP.start(@logger, "127.0.0.1", 30150, 2.0) { |s|
            s.send(cmd, 10.0)
          }.should be_kind_of(Castoro::Protocol::Response::Status)
        end
      end

      context "when received DUMP command" do
        before do
          @c.start
        end

        it "@repository#dump should be called once." do
          cmd = Castoro::Protocol::Command::Dump.new
          @repository.should_receive(:dump).exactly(1)
          Castoro::Sender::TCP.start(@logger, "127.0.0.1", 30150, 2.0) { |s|
            s.send_and_recv_stream(cmd, 10.0)
          }
        end
      end

      context "when received a unexpected command" do
        before do
          @c.start
        end

        it "should return an error response." do
          cmd = Castoro::Protocol::Command::Get.new "1.1.1"
          res = Castoro::Sender::TCP.start(@logger, "127.0.0.1", 30150, 10.0) { |s|
            s.send(cmd, 10.0)
          }
          res.should be_kind_of(Castoro::Protocol::Response)
          res.error?.should be_true
          res.error["code"].should    == "Castoro::GatewayError"
          res.error["message"].should == "only Status, Dump and Nop are acceptable."
        end
      end

      context "when stop" do
        before do
          @c.start
        end
    
        it "#alive? should be false." do
          @c.stop
          @c.alive?.should be_false
        end

        it "@tcp_server should be closed." do
          @c.instance_variable_get(:@tcp_server).close
          tcpserv = mock TCPServer
          tcpserv.stub!(:close)
          tcpserv.stub!(:closed?).and_return false

          tcpserv.should_receive(:close).exactly(1)
          @c.instance_variable_set(:@tcp_server, tcpserv)
          @c.stop
        end

        it "@tcp_server should be nil." do
          @c.stop
          @c.instance_variable_get(:@tcp_server).should be_nil
        end

        it "@thread#join should be called once." do
          @c.instance_variable_get(:@thread).should_receive(:join).exactly(1)
          @c.stop
        end

        it "@thread should be nil." do
          @c.stop
          @c.instance_variable_get(:@thread).should be_nil
        end

        it "should return self." do
          @c.stop.should == @c
        end
      end
    end
  end

  after do
    @repository = nil

    @c.stop if @c.alive? rescue nil
    @c = nil
  end
end
