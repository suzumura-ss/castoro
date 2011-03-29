require File.dirname(__FILE__) + '/spec_helper.rb'

require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'

IP     = '192.168.0.1'
PORT   = '30150'
BASKET = '1234567'

UDP_HEADER1         = "[\"#{IP}\", #{PORT}, #{BASKET}]"                              + "\r\n"
INVALID_UDP_HEADER1 = "[\"hoge\", #{PORT}, #{BASKET}]"                               + "\r\n"
INVALID_UDP_HEADER2 = "[\"#{IP}\", \"hoge\", #{BASKET}]"                             + "\r\n"
INVALID_UDP_HEADER3 = "[\"#{IP}\", #{PORT}, \"hoge\"]"                               + "\r\n"
INVALID_UDP_HEADER4 = "[\"#{IP}\", #{PORT}]"                                         + "\r\n"
INVALID_UDP_HEADER5 = "[\"#{IP}\", #{PORT}, #{BASKET}, \"hoge\"]"                    + "\r\n"
INVALID_REQUEST1    = "[\"1.1\", \"D\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
INVALID_REQUEST2    = "[\"1.3\", \"C\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
INVALID_REQUEST3    = "[ 1.1 ,   \"C\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
INVALID_REQUEST4    = "[\"1.1\", \"C\", \"create\", {\"foo\":\"bar\"}]"              + "\r\n"
INVALID_REQUEST5    = "[\"1.1\", \"C\", \"CREATE\", {\"foo\":\"bar\"}, \"hoge\"]"    + "\r\n"
INVALID_REQUEST6    = "[\"1.1\", \"C\", \"CREATE\"]"                                 + "\r\n"
INVALID_REQUEST7    = "[\"1.1\", \"C\", \"CREATE\",100]"                             + "\r\n"
INVALID_REQUEST8    = "[\"1.1\", \"R\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
INVALID_REQUEST9    = "String"
INVALID_REQUEST10   = 100
REQUEST1            = "[\"1.1\", \"C\", \"FINALIZE\", {\"foo\":\"bar\"}]"            + "\r\n"
REQUEST2            = "[\"1.1\", \"C\", \"CREATE\", {\"foo\":\"bar\",\"hoge\":100}]" + "\r\n"


describe Castoro::Peer::UdpServerChannel do

  it 'PROTOCOL_VERSION should "1.1"' do
    Castoro::Peer::PROTOCOL_VERSION.should == "1.1"
  end

  before do
    @channel = Castoro::Peer::UdpServerChannel.new
  end

  context 'when initialize' do
    it 'shoud have methods of Castoro::Peer::UdpServerChannel.' do
      @channel.should respond_to(:parse, :send, :receive, :tcp?)
    end

    it '#parse should raise Error.' do
      Proc.new{
        @channel.parse
      }.should raise_error
    end
    
    it '#tcp? should return false' do
      @channel.tcp?.should be_false
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
    
    context "#{INVALID_UDP_HEADER1}#{REQUEST1}" do
      it 'should raise BadRequestError.' do
        pending 'this case should be checked and rescued.'
        @channel.instance_variable_set(:@data, INVALID_UDP_HEADER1 + REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{INVALID_UDP_HEADER2}#{REQUEST1}" do
      it 'should raise BadRequestError.' do
        pending 'this case should be checked and rescued.'
        @channel.instance_variable_set(:@data, INVALID_UDP_HEADER2 + REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{INVALID_UDP_HEADER3}#{REQUEST1}" do
      it 'should raise BadRequestError.' do
        pending 'this case should be checked and rescued.'
        @channel.instance_variable_set(:@data, INVALID_UDP_HEADER3 + REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{INVALID_UDP_HEADER4}#{REQUEST1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_UDP_HEADER4 + REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{INVALID_UDP_HEADER5}#{REQUEST1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, INVALID_UDP_HEADER5 + REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{UDP_HEADER1}#{INVALID_REQUEST1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{UDP_HEADER1}#{INVALID_REQUEST2}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST2)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST3}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST3)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST4}" do
      it 'should raise BadRequestError.' do
        pending 'do not need to check command to be correct.'
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST4)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST5}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST5)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST6}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST6)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST7}" do
      it 'should raise BadRequestError.' do
        pending 'do not need to check fourth argument to be Hash.'
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST7)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST8}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST8)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{UDP_HEADER1}#{INVALID_REQUEST9}" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + INVALID_REQUEST9)
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


    context "#{UDP_HEADER1}#{REQUEST1}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + REQUEST1)
        @channel.parse.should == ["FINALIZE",{"foo"=>"bar"}]
        @channel.instance_variable_get(:@command).should == "FINALIZE"
      end
    end

    context "#{UDP_HEADER1}#{REQUEST2}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, UDP_HEADER1 + REQUEST2)
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
      @socket.stub!(:sending)
      Socket.stub!(:unpack_sockaddr_in).and_return("30150", "192.168.0.1")
      Castoro::Peer::ExtendedUDPSocket.stub!(:new).and_return(@socket)
    end

    context 'with' do
      context 'invalid socket' do
        it 'should raise InternalServerError.' do
          pending "this case should be checked and rescued."
          Proc.new{
            @channel.send("socket", {"bar" => "100"})
          }.should raise_error(Castoro::Peer::InternalServerError)
        end
      end

      context 'invalid ticket' do
        it 'should raise InternalServerError.' do
          pending "this case should be checked and rescued."
          Proc.new{
            @channel.send(@socket, {"bar" => "100"}, "ticket")
          }.should raise_error(Castoro::Peer::InternalServerError)
        end
      end

      context '(socket, {"bar" => "100"})' do
        it 'should call Castoro::Peer::ExtendedUDPSocket#sending.' do
          @socket.should_receive(:sending).with("\r\n#{["1.1","R",nil,{"bar"=>"100"}].to_json}\r\n",nil,nil,nil)
          @channel.send(@socket,{"bar" => "100"})
        end
      end

      context '(socket, {"bar" => "100"}, ticket)' do
        it 'should call Castoro::Peer::ExtendedUDPSocket#sending.' do
          @socket.should_receive(:sending).with("\r\n#{["1.1","R",nil,{"bar"=>"100"}].to_json}\r\n",nil,nil,an_instance_of(Castoro::Peer::Ticket))
          @channel.send(@socket,{"bar" => "100"},@ticket)
        end
      end

      context '(socket, error)' do
        it 'should call Castoro::Peer::ExtendedUDPSocket#sending.' do
          @socket.should_receive(:sending).with("\r\n#{["1.1","R",nil,{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n",nil,nil,nil)
          @channel.send(@socket,@error)
        end
      end

      context '(socket, error, ticket)' do
        it 'should call Castoro::Peer::ExtendedUDPSocket#sending.' do
          @socket.should_receive(:sending).with("\r\n#{["1.1","R",nil,{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n",nil,nil,an_instance_of(Castoro::Peer::Ticket))
          @channel.send(@socket,@error,@ticket)
        end
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
      @socket.stub!(:getpeername)
      @socket.stub!(:sending)
      Socket.stub!(:unpack_sockaddr_in).and_return("30150", "192.168.0.1")
      Castoro::Peer::ExtendedUDPSocket.stub!(:new).and_return(@socket)
      @channel.instance_variable_set(:@data, UDP_HEADER1 + REQUEST1)
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{UDP_HEADER1}#{["1.1","R","FINALIZE",{"bar"=>"100"}].to_json}\r\n", "192.168.0.1", 30150, nil)
      @channel.send(@socket,{"bar" => "100"})
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{UDP_HEADER1}#{["1.1","R","FINALIZE",{"bar"=>"100"}].to_json}\r\n", "192.168.0.1", 30150, an_instance_of(Castoro::Peer::Ticket))
      @channel.send(@socket, {"bar" => "100"}, @ticket)
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{UDP_HEADER1}#{["1.1","R","FINALIZE",{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n", "192.168.0.1", 30150, nil) 
      @channel.send(@socket,@error)
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{UDP_HEADER1}#{["1.1","R","FINALIZE",{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n", "192.168.0.1", 30150, an_instance_of(Castoro::Peer::Ticket))
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

