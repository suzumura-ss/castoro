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

require "thread"

class ReceiverMock
  @@requests = []
  def self.receive header, data, port, ip
    ret =
      case data
      when Castoro::Protocol::Command::Get
        basket = data.basket
        paths = {
          "peer1" => "foo/bar/baz",
          "peer2" => "foo/bar/baz",
        }
        Castoro::Protocol::Response::Get.new nil, basket, paths

      else
        #
      end
    @@requests << [header, ret, 12345, "127.0.0.1"]
  end

  def initialize logger, port, on_received
    @on_received = on_received
    @locker = Mutex.new
  end
  def start
    @locker.synchronize {
      @thread = Thread.fork {
        begin
          until Thread.current[:dying]
            if (ret = @@requests.shift)
              header, data, port, ip = ret
              @on_received.call header, data, port, ip
            end
          end
        rescue => e
          puts e.message + "\n" + e.backtrace.join("\n\t")
        end
      }
    }
  end
  def stop
    @locker.synchronize {
      @thread[:dying] = true
      @thread.wakeup rescue nil
      @thread.join
      @thread = nil
    }
  end
  def alive?; !! @thread; end
end

class SenderMock
  def initialize; end
  def start; end
  def stop; end
  def send header, data, port, ip
    ReceiverMock.receive(header, data, port, ip)
  end
end


#describe Castoro::Client do
#  before do
#    Castoro::Sender::UDP.stub!(:new) { SenderMock.new }
#    Castoro::Receiver::UDP.stub!(:new) { |logger, port, on_received|
#      ReceiverMock.new(logger, port, on_received)
#    }
#  end
#
#  context "" do
#    before do
#      conf = {
#        "logger" => Logger.new(nil),
#        "my_host" => "127.0.0.1",
#      }
#      @client = Castoro::Client.new conf
#    end
#
#    it "should be able to open" do
#      @client.open
#    end
#
#    context "When opened" do
#      before do
#        @client.open
#      end
#
#      it "" do
#        key = Castoro::BasketKey.new(1, 2, 3)
#        res = @client.get key
#        puts res
#      end
#
#      after do
#        @client.close
#      end
#    end
#
#    after do
#      @client.close rescue nil
#      @client = nil
#    end
#  end
#
#  after do
#    #
#  end
#end
#
