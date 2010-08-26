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


describe Castoro::Protocol::UDPHeader do

  context 'when argument for Protocol::UDPHeader#parse is' do
    context '"{"222.333.1.1",100,200}"' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.parse '{"222.333.1.1",100,200}'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '"["222.333.1.1",100]"' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.parse '["222.333.1.1",100]'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '"["222.333.1.1",100,200,"hoge"]"' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.parse '["222.333.1.1",100,200,"hoge"]'
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '"["222.333.1.1",100,200]"' do
      it 'should be able to create an instance of Protocol::UDPHeader' do
        udp = Castoro::Protocol::UDPHeader.parse '["222.333.1.1",100,200]'
        udp.should be_kind_of Castoro::Protocol::UDPHeader
      end
    end
  end


  context 'when argument for Protocol::UDPHeader#new is' do
    context '("222.333.1.1",10000000000000000000000000000000,200)' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.new "222.333.1.1",10000000000000000000000000000000,200
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '("222.333.1.1","100",200)' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.new "222.333.1.1","100",200
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '("222.333.1.1",[100],200)' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.new "222.333.1.1",[100],200
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '("222.333.1.1",100,"200")' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.new "222.333.1.1",100,"200"
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '("222.333.1.1",100,[200])' do
      it 'should raise ProtocolError' do
        Proc.new{
          Castoro::Protocol::UDPHeader.new "222.333.1.1",100,[200]
        }.should raise_error(Castoro::ProtocolError)
      end
    end

    context '("222.333.1.1",100,200)' do
      before do
        @udp = Castoro::Protocol::UDPHeader.new "222.333.1.1",100,200
      end

      it 'should be able to create an instance of Protocol::UDPHeader' do
        @udp.should be_kind_of Castoro::Protocol::UDPHeader
      end

      it 'should be able to use #to_s' do
        @udp.to_s.should == '["222.333.1.1",100,200]' + "\r\n"
      end

      it 'should be able to get :ip' do
        @udp.ip.should == "222.333.1.1"
      end

      it 'should be able to get :port' do
        @udp.port.should == 100
      end

      it 'should be able to get :sid' do
        @udp.sid.should == 200
      end

      after do
        @udp = nil
      end
    end

    context '("222.333.1.1",100)' do
      before do
        @udp = Castoro::Protocol::UDPHeader.new "222.333.1.1",100
      end

      it 'should be able to create an instance of Protocol::UDPHeader' do
        @udp.should be_kind_of Castoro::Protocol::UDPHeader
      end

      it 'should be able to use #to_s' do
        @udp.to_s.should == '["222.333.1.1",100,0]' + "\r\n"
      end

      it 'should be able to get :ip' do
        @udp.ip.should == "222.333.1.1"
      end

      it 'should be able to get :port' do
        @udp.port.should == 100
      end

      it 'should be able to get :sid' do
        @udp.sid.should == 0
      end


      after do
        @udp = nil
      end
    end
  end
end
