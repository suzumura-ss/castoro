require File.dirname(__FILE__) + '/spec_helper.rb'

require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'

INVALID_REQUEST1  = '["1.1", "D", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST2  = '["1.3", "C", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST3  = '[ 1.1 , "C", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST4  = '["1.1", "C", "create", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST5  = '["1.1", "C", "CREATE", {"foo":"bar"}, "hoge"]'    + "\r\n"
INVALID_REQUEST6  = '["1.1", "C", "CREATE"]'                           + "\r\n"
INVALID_REQUEST7  = '["1.1", "C", "CREATE",100]'                       + "\r\n"
INVALID_REQUEST8  = '["1.1", "R", "CREATE", {"foo":"bar"}]'            + "\r\n"
INVALID_REQUEST9  = 'String'
INVALID_REQUEST10 = 100
REQUEST1          = '["1.1", "C", "FINALIZE", {"foo":"bar"}]'          + "\r\n"
REQUEST2          = '["1.1", "C", "CREATE",{ "foo":"bar","hoge":100}]' + "\r\n"

describe Castoro::Peer::TcpServerChannel do

  it 'PROTOCOL_VERSION should "1.1"' do
    Castoro::Peer::PROTOCOL_VERSION.should == "1.1"
  end

  before do
    @channel = Castoro::Peer::TcpServerChannel.new
  end

  context 'when initialize' do
    it 'instance variables should be nil.' do
      @channel.instance_variable_get(:@command).should be_nil
      @channel.get_peeraddr.should == [nil, nil]
    end

    it 'shoud have methods of Castoro::Peer::TcpServerChannel.' do
      @channel.should respond_to(:parse, :send, :receive, :get_peeraddr, :closed?, :tcp?)
    end

    it '#parse should raise Error.' do
      Proc.new{
        @channel.parse
      }.should raise_error
    end
    
    it '#closed? should return true' do
      @channel.closed?.should be_true
    end
    
    it '#tcp? should return true' do
      @channel.tcp?.should be_true
    end
  end

  
  context 'when #parse if @data is' do
    context "nil" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, nil)
        Proc.new{
          @channel.parse
        }.should raise_error
      end
    end
    
    context "#{INVALID_REQUEST1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{INVALID_REQUEST2}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST2)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST3}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST3)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST4}" do
      it 'should raise BadRequestError.' do
        pending 'now do not need to check command to be correct.'
        @channel.instance_variable_set(:@data, INVALID_REQUEST3)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST5}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST5)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST6}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST6)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST7}" do
      it 'do not need to check fourth argument to be Hash.' do
      end
    end

    context "#{INVALID_REQUEST8}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST8)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{INVALID_REQUEST9}" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST9)
        Proc.new{
          @channel.parse
        }.should raise_error
      end
    end

    context "#{INVALID_REQUEST10}" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, INVALID_REQUEST10)
        Proc.new{
          @channel.parse
        }.should raise_error
      end
    end


    context "#{REQUEST1}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, REQUEST1)
        @channel.parse.should == ["FINALIZE",{"foo"=>"bar"}]
        @channel.instance_variable_get(:@command).should == "FINALIZE"
      end
    end

    context "#{REQUEST2}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, REQUEST2)
        @channel.parse.should == ["CREATE",{"foo"=>"bar","hoge"=>100}]
        @channel.instance_variable_get(:@command).should == "CREATE"
      end
    end
  end

  context "when #send" do
    before do
      @ticket = Castoro::Peer::Ticket.new
      @error  = RuntimeError.new "exception message"
      @socket = mock(Castoro::Peer::ExtendedUDPSocket)
      @socket.stub!(:getpeername)
      @socket.stub!(:syswrite)
      Socket.stub!(:unpack_sockaddr_in).and_return("30150", "192.168.0.1")
      Castoro::Peer::ExtendedUDPSocket.stub!(:new).and_return(@socket)
    end

    context 'with' do
      context 'invalid socket' do
        it 'should raise_error.' do
          pending 'do not need to check to be correct socket.'
          Proc.new{
            @channel.send("hoge",{"bar" => "100"})
          }.should raise_error(BadRequestError)
        end
      end

      context 'invalid ticket' do
        it 'should raise_error.' do
          pending 'do not need to check to be correct ticket.'
          Proc.new{
            @channel.send(@socket, "hoge")
          }.should raise_error(BadRequestError)
        end
      end

      context '(socket, {"bar" => "100"})' do
        it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
          @socket.should_receive(:syswrite).with("#{["1.1","R",nil,{"bar"=>"100"}].to_json}\r\n")
          @channel.send(@socket,{"bar" => "100"})
        end
      end

      context '(socket, {"bar" => "100"}, ticket)' do
        it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
          @socket.should_receive(:syswrite).with("#{["1.1","R",nil,{"bar"=>"100"}].to_json}\r\n")
          @channel.send(@socket,{"bar" => "100"},@ticket)
        end
      end

      context '(socket, error)' do
        it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
          @socket.should_receive(:syswrite).with("#{["1.1","R",nil,{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n")
          @channel.send(@socket,@error)
        end
      end

      context '(socket, error, ticket)' do
        it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
          @socket.should_receive(:syswrite).with("#{["1.1","R",nil,{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n")
          @channel.send(@socket,@error,@ticket)
        end
      end
    end

    it 'no memory leak.' do
      scket = Castoro::Peer::ExtendedUDPSocket.new
      10000.times{@channel.send(@socket, {})}
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
      @socket.stub!(:getpeername)
      @socket.stub!(:syswrite)
      Socket.stub!(:unpack_sockaddr_in).and_return("30150", "192.168.0.1")
      Castoro::Peer::ExtendedUDPSocket.stub!(:new).and_return(@socket)
      @channel.instance_variable_set(:@data, REQUEST1)
    end

    it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
      @channel.parse
      @ticket.should_receive(:mark).exactly(0)
      @socket.should_receive(:syswrite).with("#{["1.1","R","FINALIZE",{"bar"=>"100"}].to_json}\r\n")
      @channel.send(@socket,{"bar" => "100"})
    end

    it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
      @channel.parse
      @ticket.should_receive(:mark).exactly(2)
      @socket.should_receive(:syswrite).with("#{["1.1","R","FINALIZE",{"bar"=>"100"}].to_json}\r\n")
      @channel.send(@socket, {"bar" => "100"}, @ticket)
    end

    it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
      @channel.parse
      @ticket.should_receive(:mark).exactly(0)
      @socket.should_receive(:syswrite).with("#{["1.1","R","FINALIZE",{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n")
      @channel.send(@socket,@error)
    end

    it 'should be called Castoro::Peer::ExtendedUDPSocket#syswrite.' do
      @channel.parse
      @ticket.should_receive(:mark).exactly(2)
      @socket.should_receive(:syswrite).with("#{["1.1","R","FINALIZE",{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n")
      @channel.send(@socket,@error,@ticket)
    end

    after do
      @socket = nil
    end
  end

  after do
    @channel = nil
  end
    
end

