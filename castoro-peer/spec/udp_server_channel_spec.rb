require File.dirname(__FILE__) + '/spec_helper.rb'

require 'castoro-peer/channel'
require 'castoro-peer/extended_udp_socket'

describe Castoro::Peer::UdpServerChannel do
  before do
    @ip                  = "192.168.0.1"
    @port                = 30150
    @basket              = "1234567"
    @udp_header1         = "[\"#{@ip}\", #{@port}, #{@basket}]"                           + "\r\n"
    @invalid_udp_header1 = "[\"hoge\", #{@port}, #{@basket}]"                             + "\r\n"
    @invalid_udp_header2 = "[\"#{@ip}\", \"hoge\", #{@basket}]"                           + "\r\n"
    @invalid_udp_header3 = "[\"#{@ip}\", #{@port}, \"hoge\"]"                             + "\r\n"
    @invalid_udp_header4 = "[\"#{@ip}\", #{@port}]"                                       + "\r\n"
    @invalid_udp_header5 = "[\"#{@ip}\", #{@port}, #{@basket}, \"hoge\"]"                 + "\r\n"
    @invalid_request1    = "[\"1.1\", \"D\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
    @invalid_request2    = "[\"1.3\", \"C\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
    @invalid_request3    = "[ 1.1 ,   \"C\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
    @invalid_request4    = "[\"1.1\", \"C\", \"create\", {\"foo\":\"bar\"}]"              + "\r\n"
    @invalid_request5    = "[\"1.1\", \"C\", \"CREATE\", {\"foo\":\"bar\"}, \"hoge\"]"    + "\r\n"
    @invalid_request6    = "[\"1.1\", \"C\", \"CREATE\"]"                                 + "\r\n"
    @invalid_request7    = "[\"1.1\", \"C\", \"CREATE\",100]"                             + "\r\n"
    @invalid_request8    = "[\"1.1\", \"R\", \"CREATE\", {\"foo\":\"bar\"}]"              + "\r\n"
    @invalid_request9    = "String"
    @invalid_request10   = 100
    @request1            = "[\"1.1\", \"C\", \"FINALIZE\", {\"foo\":\"bar\"}]"            + "\r\n"
    @request2            = "[\"1.1\", \"C\", \"CREATE\", {\"foo\":\"bar\",\"hoge\":100}]" + "\r\n"
  end

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
    
    context "#{@invalid_udp_header1}#{@request1}" do
      it 'should raise BadRequestError.' do
        pending 'this case should be checked and rescued.'
        @channel.instance_variable_set(:@data, @invalid_udp_header1 + @request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@invalid_udp_header2}#{@request1}" do
      it 'should raise BadRequestError.' do
        pending 'this case should be checked and rescued.'
        @channel.instance_variable_set(:@data, @invalid_udp_header2 + @request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@invalid_udp_header3}#{@request1}" do
      it 'should raise BadRequestError.' do
        pending 'this case should be checked and rescued.'
        @channel.instance_variable_set(:@data, @invalid_udp_header3 + @request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@invalid_udp_header4}#{@request1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_udp_header4 + @request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@invalid_udp_header5}#{@request1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @invalid_udp_header5 + @request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@udp_header1}#{@invalid_request1}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request1)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end
    
    context "#{@udp_header1}#{@invalid_request2}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request2)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request3}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request3)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request4}" do
      it 'should raise BadRequestError.' do
        pending 'do not need to check command to be correct.'
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request4)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request5}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request5)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request6}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request6)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request7}" do
      it 'should raise BadRequestError.' do
        pending 'do not need to check fourth argument to be Hash.'
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request7)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request8}" do
      it 'should raise BadRequestError.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request8)
        Proc.new{
          @channel.parse
        }.should raise_error(Castoro::Peer::BadRequestError)
      end
    end

    context "#{@udp_header1}#{@invalid_request9}" do
      it 'should raise Error.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @invalid_request9)
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


    context "#{@udp_header1}#{@request1}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @request1)
        @channel.parse.should == ["FINALIZE",{"foo"=>"bar"}]
        @channel.instance_variable_get(:@command).should == "FINALIZE"
      end
    end

    context "#{@udp_header1}#{@request2}" do
      it 'should return command and hash.' do
        @channel.instance_variable_set(:@data, @udp_header1 + @request2)
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
      @channel.instance_variable_set(:@data, @udp_header1 + @request1)
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{@udp_header1}#{["1.1","R","FINALIZE",{"bar"=>"100"}].to_json}\r\n", "192.168.0.1", 30150, nil)
      @channel.send(@socket,{"bar" => "100"})
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{@udp_header1}#{["1.1","R","FINALIZE",{"bar"=>"100"}].to_json}\r\n", "192.168.0.1", 30150, an_instance_of(Castoro::Peer::Ticket))
      @channel.send(@socket, {"bar" => "100"}, @ticket)
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{@udp_header1}#{["1.1","R","FINALIZE",{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n", "192.168.0.1", 30150, nil) 
      @channel.send(@socket,@error)
    end

    it 'instance valiables should be setted and used in send.' do
      @channel.parse
      @socket.should_receive(:sending).with("#{@udp_header1}#{["1.1","R","FINALIZE",{"error"=>{"code"=>"RuntimeError","message"=>"exception message"}}].to_json}\r\n", "192.168.0.1", 30150, an_instance_of(Castoro::Peer::Ticket))
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

