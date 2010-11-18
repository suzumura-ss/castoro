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

require 'castoro-peer/configurations'

require 'fileutils'
require 'tempfile'

describe Castoro::Peer::Configurations do

  before do
    @basket_dir         = Dir.mktmpdir('expdsk')
    @manipulator_socket = Tempfile.new('manipulator.sock')
    @conf               = Tempfile.new('peer.conf')

    @conf.puts <<_END_OF_CONFIG_
---
hostname_for_client: peer01
basket_base_dir: #{@basket_dir}
multicast_if: 127.0.0.1
replication_transmission_datasize: 1048576
use_manipulator_daemon: true
manipulator_socket: #{@manipulator_socket.path}
groups:
  - [ peer01, peer02, peer03 ]
  - [ peer04, peer05, peer06 ]
  - [ peer07, peer08, peer09 ]
  - [ peer10, peer11, peer12 ]
aliases:
  peer01: peer01.repl
  peer02: peer02
  peer03: peer03.repl
dir_w_user: root
dir_w_group: root
dir_a_user: root
dir_a_group: root
dir_d_user: root
dir_d_group: root
dir_c_user: root
dir_c_group: root
_END_OF_CONFIG_
    @conf.close
  end

  describe "#storage_servers" do
    before do
      @c = Castoro::Peer::Configurations.new @conf.path
    end

    it "#colleague_hosts equals ['peer02', 'peer03.repl']" do
      @c.storage_servers.colleague_hosts.should   == ["peer02", "peer03.repl"]
    end

    it "#target should equals 'peer01.repl'" do
      @c.storage_servers.target                   == "peer01.repl"
    end

    it "#alternative_hosts equals ['peer03.repl']" do
      @c.storage_servers.alternative_hosts.should == ["peer03.repl"]
    end
  end

  after do
    @conf.unlink if File.file? @conf.path
    @manipulator_socket.unlink if File.file? @manipulator_socket
    FileUtils.rm_r @basket_dir
  end

end

