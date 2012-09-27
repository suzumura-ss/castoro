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

begin
  require 'spec'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'castoro-peer/configurations'

module Castoro
  module Peer
    remove_const :Configurations
    class Configurations
      # mock for Castoro::Peer::Configurations.
      #HostnameForClient = "host5"
      #StorageHosts = {"host1"=> "host1rep","host6"=> "host6rep",}
      #StorageGroups = [["host1","host2","host3"],["host4","host5","host6","host7"],["host8","host9"]]
      #Dir_w_user    = "castoro"
      #Dir_w_group   = "castoro"
      #Dir_w_perm    = "0755"

      # mock for Castoro::Peer::Configurations.
      CONF = {
        "hostname_for_client" => "host5",
        "storage_hosts"       => {"host1"=> "host1rep","host6"=> "host6rep",},
        "storage_groups"      => [["host1","host2","host3"],["host4","host5","host6","host7"],["host8","host9"]],

        "dir_w_user"          => "castoro",
        "dir_w_group"         => "castoro",
        "dir_w_perm"          => "0755",

        "dir_a_user"          => "castoro",
        "dir_a_group"         => "castoro",
        "dir_a_perm"          => "0755",

        "dir_d_user"          => "castoro",
        "dir_d_group"         => "castoro",
        "dir_d_perm"          => "0755",

        "dir_c_user"          => "castoro",
        "dir_c_group"         => "castoro",
        "dir_c_perm"          => "0755",
      }

      CONF1 = CONF.merge({
        "hostname_for_client" => "host",
      })

      @@type = nil
      def self.type; @@type; end
      def self.type=(val); @@type = val; end

      def initialize conf
        @hostname_for_client = conf["hostname_for_client"]
        @storage_hosts       = conf["storage_hosts"]
        @storage_groups      = conf["storage_groups"]
        @dir_w_user          = conf["dir_w_user"]
        @dir_w_group         = conf["dir_w_group"]
        @dir_w_perm          = conf["dir_w_perm"]
        @dir_a_user          = conf["dir_a_user"]
        @dir_a_group         = conf["dir_a_group"]
        @dir_a_perm          = conf["dir_a_perm"]
        @dir_d_user          = conf["dir_d_user"]
        @dir_d_group         = conf["dir_d_group"]
        @dir_d_perm          = conf["dir_d_perm"]
        @dir_c_user          = conf["dir_c_user"]
        @dir_c_group         = conf["dir_c_group"]
        @dir_c_perm          = conf["dir_c_perm"]
      end

      @@conf  = Configurations.new(CONF)
      @@conf1 = Configurations.new(CONF1)

      def self.instance
        case @@type
        when 1; @@conf1
        else  ; @@conf
        end
      end

      def HostnameForClient; @hostname_for_client; end
      def StorageHostsData;  @storage_hosts; end
      def StorageGroupsData; @storage_groups; end
      def Dir_w_user;        @dir_w_user;  end
      def Dir_w_group;       @dir_w_group; end
      def Dir_w_perm;        @dir_w_perm;  end
      def Dir_a_user;        @dir_a_user;  end
      def Dir_a_group;       @dir_a_group; end
      def Dir_a_perm;        @dir_a_perm;  end
      def Dir_d_user;        @dir_d_user;  end
      def Dir_d_group;       @dir_d_group; end
      def Dir_d_perm;        @dir_d_perm;  end
      def Dir_c_user;        @dir_c_user;  end
      def Dir_c_group;       @dir_c_group; end
      def Dir_c_perm;        @dir_c_perm;  end

    end
  end
end
