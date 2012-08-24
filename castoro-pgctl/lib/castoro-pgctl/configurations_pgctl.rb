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

require 'singleton'
require 'castoro-pgctl/configurations_base'

module Castoro
  module Peer

    module Configurations
      class Pgctl < Base
        include Singleton

        @@file = DEFAULT_FILE = '/etc/castoro/pgctl.conf'

        def self.file= file
          @@file = file
        end

        def configuration_file
          @@file
        end

        def get_configuration_file_instance file
          ConfigurationFile.new file
        end


        class ConfigurationFile < ConfigurationFileBase
          def get_global_section_instance
            GlobalSection.new
          end

          def get_service_section_instance
            ServiceSection.new
          end

          def validate
            super
            validate_password_file
          end

          private
          
          def validate_password_file
            file = @global.data[ :pgctl_password_file ]
            back = @global.data[ :pgctl_password_backupfile ]

            file != back or raise ArgumentError, "the password file and password backup file should not equal each other: #{file} #{back}"
            x = File.dirname file
            y = File.dirname back
            x == y or raise ArgumentError, "The directory for the password file and the one for the backup file should be same: #{x} #{y}"
            File.exists?( x ) or raise ArgumentError, "The directory for the password and backup file does not exist: #{x}"
            if File.exists?( file )
              File.readable?( file ) or raise ArgumentError, "The password file exists, but it is not readable: #{file}"
            end
          end
        end


        class GlobalSection < Section
          def initialize
            super(
                  :effective_user                             => [ :mandatory, :string ],
                  :basket_basedir                             => [ :mandatory, :string, :optional_path ],
                  :peer_config_file                           => [ :mandatory, :string, :optional_path ],
                  :cmond_maintenance_tcpport                  => [ :mandatory, :number ],
                  :cpeerd_maintenance_tcpport                 => [ :mandatory, :number ],
                  :crepd_maintenance_tcpport                  => [ :mandatory, :number ],
                  :cstartd_comm_tcpport                       => [ :mandatory, :number ],
                  :cagentd_comm_tcpport                       => [ :mandatory, :number ],
                  :cstartd_ps_command                         => [ :mandatory, :string, :path ],
                  :cstartd_ps_options                         => [ :mandatory, :string, :shell_escape ],
                  :pgctl_password_file                        => [ :mandatory, :string, :optional_path ],
                  :pgctl_password_filemode                    => [ :mandatory, :octal ],
                  :pgctl_password_backupfile                  => [ :mandatory, :string, :optional_path ],
                  :pgctl_password_attemptlimit                => [ :mandatory, :number ],
                  :pgctl_uploading_confirmationinterval       => [ :mandatory, :number ],
                  :pgctl_uploading_confirmationcount          => [ :mandatory, :number ],
                  :pgctl_replication_confirmationinterval     => [ :mandatory, :number ],
                  :pgctl_replication_confirmationcount        => [ :mandatory, :number ],
                  :cagentd_uploading_timetolerance            => [ :mandatory, :number ],
                  :cagentd_receiving_timetolerance            => [ :mandatory, :number ],
                  )
          end
        end


        class ServiceSection < Section
          def initialize
            raise ArgumentError, "section is not allowed in this configration file"
          end
        end
      end
    end

  end
end

if $0 == __FILE__
  module Castoro
    module Peer
      c = Configurations::Pgctl
      c.file = '../../etc/castoro/pgctl.conf-sample-ja.conf'
      p c.instance
    end
  end
end

