require File.dirname(__FILE__) + '/spec_helper.rb'

require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'

INVALID_REQUEST1 = '["1.1", "D", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST2 = '["1.3", "C", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST3 = '[ 1.1 , "C", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST4 = '["1.1", "C", "create", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST5 = '["1.1", "C", "CREATE", {"foo":"bar"}, "hoge"]'    + "\r\n"
INVALID_REQUEST6 = '["1.1", "C", "CREATE"]'                           + "\r\n"
INVALID_REQUEST7 = '["1.1", "C", "CREATE", 100]'                      + "\r\n"
INVALID_REQUEST8 = '["1.1", "R", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST9  = 'String'
INVALID_REQUEST10 = 100
REQUEST1         = '["1.1", "C", "FINALIZE",{"foo":"bar"}]'           + "\r\n"
REQUEST2         = '["1.1", "C", "CREATE", {"foo":"bar","hoge":100}]' + "\r\n"

describe Castoro::Peer::ServerChannel do

  it 'PROTOCOL_VERSION should "1.1"' do
    Castoro::Peer::PROTOCOL_VERSION.should == "1.1"
  end

  before do
    @channel = Castoro::Peer::ServerChannel.new
  end

  context 'when initialize' do
    it '@command should be nil.' do
      @channel.instance_variable_get(:@command).should be_nil
    end

    it 'shoud have methods of Castoro::Peer::ServerChannel.' do
      @channel.should respond_to(:parse, :send)
    end
  end

  context 'when #parse with' do
    context "nil" do
      it 'should raise Error.' do
        Proc.new{
          @channel.parse(nil)
        }.should raise_error
      end
    end

     context "#{INVALID_REQUEST1}" do
      it 'should raise BadRequestError.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST1)
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{INVALID_REQUEST2}" do
      it 'should raise BadRequestError.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST2)
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST3}" do
      it 'should raise BadRequestError.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST3)
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST4}" do
      it 'do not need to check command name to be correct.' do
      end
    end

    context "#{INVALID_REQUEST5}" do
      it 'should raise BadRequestError.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST5)
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST6}" do
      it 'should raise BadRequestError.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST6)
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST7}" do
      it 'do not need to check fourth argument to be Hash.' do
      end
    end

    context "#{INVALID_REQUEST8}" do
      it 'should raise BadRequestError.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST8)
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST9}" do
      it 'should raise Error.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST9)
        }.should raise_error
      end
    end

    context "#{INVALID_REQUEST10}" do
      it 'should raise Error.' do
        Proc.new{
          @channel.parse(INVALID_REQUEST10)
        }.should raise_error
      end
    end


    context "#{REQUEST1}" do
      it 'should return command and hash.' do
        @channel.parse(REQUEST1).should == ["FINALIZE",{"foo"=>"bar"}]
        @channel.instance_variable_get(:@command).should == "FINALIZE"
      end
    end

    context "#{REQUEST2}" do
      it 'should return command and hash.' do
        @channel.parse(REQUEST2).should == ["CREATE",{"foo"=>"bar","hoge"=>100}]
        @channel.instance_variable_get(:@command).should == "CREATE"
      end
    end
  end

  context "when #send with" do
    before do
      @ticket = Castoro::Peer::Ticket.new
      @error  = RuntimeError.new "exception message"
      @socket = mock(Castoro::Peer::ExtendedUDPSocket)
      Castoro::Peer::ExtendedUDPSocket.stub!(:new).and_return(@socket)
    end

    context 'invalid socket or ticket' do
      it 'do not need to check to be correct socket or ticket' do
      end
    end

    context '(socket, {"bar" => "100"})' do
      it 'should return response of Json format.' do
        @channel.send(@socket,{"bar" => "100"}).should == '["1.1","R",null,{"bar":"100"}]'
      end
    end

    context '(socket, {"bar" => "100"}, ticket)' do
      it 'should return response of Json format.' do
        @channel.send(@socket,{"bar" => "100"},@ticket).should ==  '["1.1","R",null,{"bar":"100"}]'
      end
    end

    context '(socket, error)' do
      it 'should return response of Json format.' do
        @channel.send(@socket,@error).should ==  
          '["1.1","R",null,{"error":{"code":"RuntimeError","message":"exception message"}}]'
      end
    end

    context '(socket, error, ticket)' do
      it 'should return response of Json format.' do
        @channel.send(@socket,@error,@ticket).should ==  
          '["1.1","R",null,{"error":{"code":"RuntimeError","message":"exception message"}}]'
      end
    end

    after do
      @socket = nil
      @ticket = nil
    end
  end

  context '#parse => #send' do
    before do
      @ticket = Castoro::Peer::Ticket.new
      @error  = RuntimeError.new "exception message"
      @socket = mock(Castoro::Peer::ExtendedUDPSocket)
      Castoro::Peer::ExtendedUDPSocket.stub!(:new).and_return(@socket)
    end

    it '@command should not be nil.' do
      @channel.parse REQUEST1
      @channel.send(@socket, {"bar" => "100"}).should == 
          '["1.1","R","FINALIZE",{"bar":"100"}]'
    end

    it '@command should not be nil.' do
      @channel.parse REQUEST1
      @channel.send(@socket, {"bar" => "100"}, @ticket).should == 
          '["1.1","R","FINALIZE",{"bar":"100"}]'
    end

    it '@command should not be nil.' do
      @channel.parse REQUEST1
      @channel.send(@socket, @error).should == 
          '["1.1","R","FINALIZE",{"error":{"code":"RuntimeError","message":"exception message"}}]'
    end

    it '@command should not be nil.' do
      @channel.parse REQUEST1
      @channel.send(@socket, @error, @ticket).should == 
          '["1.1","R","FINALIZE",{"error":{"code":"RuntimeError","message":"exception message"}}]'
    end

    after do
      @socket = nil
    end
  end

  after do
    @channel = nil
  end
end

