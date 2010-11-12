require File.dirname(__FILE__) + '/spec_helper.rb'

require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'

describe Castoro::Peer::TcpServerChannel do
  before do
    @invalid_request1  = '["1.1", "D", "CREATE", {"foo":"bar"}]'            + "\r\n"
    @invalid_request2  = '["1.3", "C", "CREATE", {"foo":"bar"}]'            + "\r\n"
    @invalid_request3  = '[ 1.1 , "C", "CREATE", {"foo":"bar"}]'            + "\r\n"
    @invalid_request4  = '["1.1", "C", "create", {"foo":"bar"}]'            + "\r\n"
    @invalid_request5  = '["1.1", "C", "CREATE", {"foo":"bar"}, "hoge"]'    + "\r\n"
    @invalid_request6  = '["1.1", "C", "CREATE"]'                           + "\r\n"
    @invalid_request7  = '["1.1", "C", "CREATE",100]'                       + "\r\n"
    @invalid_request8  = '["1.1", "R", "CREATE", {"foo":"bar"}]'            + "\r\n"
    @invalid_request9  = 'String'
    @invalid_request10 = 100
    @request1          = '["1.1", "C", "FINALIZE", {"foo":"bar"}]'          + "\r\n"
    @request2          = '["1.1", "C", "CREATE",{ "foo":"bar","hoge":100}]' + "\r\n"
  end

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
    
    context "#{@invalid_request1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@invalid_request2}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_request2)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@invalid_request3}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_request3)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@invalid_request4}" do
      it 'should raise BadRequestError.' do
        pending 'now do not need to check command to be correct.'
        @channel.instance_variable_set(:@data, @invalid_request3)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@invalid_request5}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_request5)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@invalid_request6}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_request6)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@invalid_request7}" do
      it 'do not need to check fourth argument to be Hash.' do
      end
    end

    context "#{@invalid_request8}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_request8)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@invalid_request9}" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, @invalid_request9)
        Proc.new{
          @channel.parse
        }.should raise_error
      end
    end

    context "#{@invalid_request10}" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, @invalid_request10)
        Proc.new{
          @channel.parse
        }.should raise_error
      end
    end


    context "#{@request1}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, @request1)
        @channel.parse.should == ["FINALIZE",{"foo"=>"bar"}]
        @channel.instance_variable_get(:@command).should == "FINALIZE"
      end
    end

    context "#{@request2}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, @request2)
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
      @channel.instance_variable_set(:@data, @request1)
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

