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

require 'castoro-peer/configurations'
require 'castoro-peer/manipulator_impl'

module Castoro
  module Peer

    class Csm

      def self.create_executor socket_file
        if socket_file
          DaemonInterface.new socket_file
        else
          CommandInterface.new
        end
      end

      class Request
        SUB_COMMANDS = [ "mkdir", "mv"  ]
        @@configurations = nil

        attr_reader :subcommand, :user, :group, :mode, :path1, :path2

        def initialize( subcommand, user, group, mode, path1, path2 = "" )
          # Uncomment the following validators, if needed
          # raise InternalServerError, "CsmRequest: Invalid subcommand: #{subcommand}" unless SUB_COMMANDS.include?( subcommand )
          # raise InternalServerError, "CsmRequest: Invalid mode, it should be an octal number: #{mode}" unless mode =~ /^0[0-7]{3,4}$/
          # raise InternalServerError, "CsmRequest: mv does not require path2: #{path2}" if subcommand == "mv" and path2 == ""
          @subcommand = subcommand
          @user       = @@configurations[user]
          @group      = @@configurations[group]
          @mode       = @@configurations[mode]
          @path1      = path1
          @path2      = path2
        end

        class Create < Request
          def initialize( path_w )
            super( 'mkdir', :dir_w_user, :dir_w_group, :dir_w_perm, path_w )
          end
        end

        class Clone < Request
          def initialize( path_a, path_w )
            super( 'copy', :dir_w_user, :dir_w_group, :dir_w_perm, path_a, path_w )
          end
        end

        class Delete < Request
          def initialize( path_a, path_d )
            super( 'mv', :dir_d_user, :dir_d_group, :dir_d_perm, path_a, path_d )
          end
        end

        class Cancel < Request
          def initialize( path_w, path_c )
            super( 'mv', :dir_c_user, :dir_c_group, :dir_c_perm, path_w, path_c )
          end
        end

        class Finalize < Request
          def initialize( path_w, path_a )
            super( 'mv', :dir_a_user, :dir_a_group, :dir_a_perm, path_w, path_a )
          end
        end

        class Catch < Request
          def initialize( path_r )
            @subcommand = 'mkdir'
            @user       = Process.euid
            @group      = Process.egid
            @mode       = '0755'
            @path1      = path_r
            @path2      = ""
          end
        end
      end
    end

  end
end
