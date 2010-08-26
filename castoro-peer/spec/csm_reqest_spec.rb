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

require 'castoro-peer/manupulator'
require 'castoro-peer/configurations'

describe Castoro::Peer::CsmRequest do
  before do
    @config = mock(Castoro::Peer::Configurations)
    @config.stub!(:UseManipulatorDaemon)
    @config.stub!(:ManipulatorSocket)
  end

  context 'when initialize' do
    context 'with( config, "hogehoge", "usr1", "grp1", "0755", "/src/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "hogehoge", "usr1", "grp1", "0755", "/src/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mkdir", "usr1", "grp1", "55", "/src/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", "grp1", "55", "/src/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mkdir", "usr1", "grp1", 0755, "/src/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", "grp1", 0755, "/src/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mkdir", "usr1", "grp1", "9999", "/src/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", "grp1", "9999", "/src/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mkdir", "usr1", "grp1", "ABCD", "/src/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", "grp1", "ABCD", "/src/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mkdir", 100, "grp1", "0755", "/src/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", 100, "grp1", "0755", "/src/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MKDIR",{"mode":"0755","user":100,"group":"grp1","source":"/src/path"}]' + "\r\n")
      end

      after do
        @csm_req = nil
      end
    end

    context 'with( config, "mkdir", "usr1", 200, "0755", "/src/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", 200, "0755", "/src/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MKDIR",{"mode":"0755","user":"usr1","group":200,"source":"/src/path"}]' + "\r\n")
      end

      after do
        @csm_req = nil
      end
    end

    context 'with( config, "mkdir", "usr1", "grp1", "0755", "/src/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", "grp1", "0755", "/src/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MKDIR",{"mode":"0755","user":"usr1","group":"grp1","source":"/src/path"}]' + "\r\n")
      end
    end

    context 'with( config, "mkdir", "usr1", "grp1", "0755", "/src/path", "/dest/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mkdir", "usr1", "grp1", "0755", "/src/path", "/dest/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly. "dest" should not exist.'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MKDIR",{"mode":"0755","user":"usr1","group":"grp1","source":"/src/path"}]' + "\r\n")
      end

      after do
        @csm_req = nil
      end
    end
    

    context 'with( config, "mv", "usr1", "grp1", "55", "/src/path", "/dest/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", "55", "/src/path", "/dest/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mv", "usr1", "grp1", 0755, "/src/path", "/dest/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", 0755, "/src/path", "/dest/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mv", "usr1", "grp1", "9999", "/src/path", "/dest/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", "9999", "/src/path", "/dest/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mv", "usr1", "grp1", "ABCD", "/src/path", "/dest/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", "ABCD", "/src/path", "/dest/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mv", "usr1", "grp1", "0755", "/src/path")' do
      it 'should raise error' do
        Proc.new{
          @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", "0755", "/src/path")
        }.should raise_error(RuntimeError)
      end
    end

    context 'with( config, "mv", 100, "grp1", "0755", "/src/path", "/dest/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", 100, "grp1", "0755", "/src/path", "/dest/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MV",{"mode":"0755","user":100,"group":"grp1","source":"/src/path","dest":"/dest/path"}]' + "\r\n")
      end

      after do
        @csm_req = nil
      end
    end

    context 'with( config, "mv", "usr1", 200, "0755", "/src/path", "/dest/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", 200, "0755", "/src/path", "/dest/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MV",{"mode":"0755","user":"usr1","group":200,"source":"/src/path","dest":"/dest/path"}]' + "\r\n")
      end

      after do
        @csm_req = nil
      end
    end

    context 'with( config, "mv", "usr1", "grp1", "0755", "/src/path", "/dest/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", "0755", "/src/path", "/dest/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MV",{"mode":"0755","user":"usr1","group":"grp1","source":"/src/path","dest":"/dest/path"}]' + "\r\n")
      end
    end

    context 'with( config, "mv", "usr1", "grp1", "0755", "/src/path", "/dest/path")' do
      before do
        @csm_req = Castoro::Peer::CsmRequest.new( @config, "mv", "usr1", "grp1", "0755", "/src/path", "/dest/path")
      end
      
      it 'should be an instance of Castoro::Peer::CsmRequest' do
        @csm_req.should be_kind_of Castoro::Peer::CsmRequest
      end

      it 'should be able to use #to_s correctly. "dest" should not exist.'do
        JSON.parse(@csm_req.to_s).should == 
          JSON.parse('["1.1","C","MV",{"mode":"0755","user":"usr1","group":"grp1","source":"/src/path","dest":"/dest/path"}]' + "\r\n")
      end

      after do
        @csm_req = nil
      end
    end
  end
end

