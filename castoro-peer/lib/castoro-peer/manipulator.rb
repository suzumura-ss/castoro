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
      def self.create_executor
        c = Configurations.instance
        if ( c.UseManipulatorDaemon )
          DaemonInterface.new( c.ManipulatorSocket )
        else
          CommandInterface.new
        end
      end

      class Request
        SUB_COMMANDS = [ "mkdir", "mv"  ]
        @@c = Configurations.instance

        attr_reader :subcommand, :user, :group, :mode, :path1, :path2

        def initialize( subcommand, user, group, mode, path1, path2 = "" )
          # Uncomment the following validators, if needed
          # raise InternalServerError, "CsmRequest: Invalid subcommand: #{subcommand}" unless SUB_COMMANDS.include?( subcommand )
          # raise InternalServerError, "CsmRequest: Invalid mode, it should be an octal number: #{mode}" unless mode =~ /^0[0-7]{3,4}$/
          # raise InternalServerError, "CsmRequest: mv does not require path2: #{path2}" if subcommand == "mv" and path2 == ""
          @subcommand = subcommand
          @user       = @@c.send user
          @group      = @@c.send group
          @mode       = @@c.send mode
          @path1      = path1
          @path2      = path2
        end

        class Create < Request
          def initialize( path_w )
            super( 'mkdir', :Dir_w_user, :Dir_w_group, :Dir_w_perm, path_w )
          end
        end

        class Delete < Request
          def initialize( path_a, path_d )
            super( 'mv', :Dir_d_user, :Dir_d_group, :Dir_d_perm, path_a, path_d )
          end
        end

        class Cancel < Request
          def initialize( path_w, path_c )
            super( 'mv', :Dir_c_user, :Dir_c_group, :Dir_c_perm, path_w, path_c )
          end
        end

        class Finalize < Request
          def initialize( path_w, path_a )
            super( 'mv', :Dir_a_user, :Dir_a_group, :Dir_a_perm, path_w, path_a )
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
