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
      end


      class ConfigurationFile < ConfigurationFileBase
      end


      class GlobalSection < Section
        def initialize
          super(
                :effective_user                             => [ :mandatory, :string ],
                :basket_basedir                             => [ :mandatory, :string, :path ],
                :peer_config_file                           => [ :mandatory, :string, :path ],
                :cmond_maintenance_tcpport                  => [ :mandatory, :number ],
                :cpeerd_maintenance_tcpport                 => [ :mandatory, :number ],
                :crepd_maintenance_tcpport                  => [ :mandatory, :number ],
                :cstartd_comm_tcpport                       => [ :mandatory, :number ],
                :cagentd_comm_tcpport                       => [ :mandatory, :number ],
                :cstartd_ps_command                         => [ :mandatory, :string, :path ],
                :cstartd_ps_options                         => [ :mandatory, :string, :shell_escape ],
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

if $0 == __FILE__
  module Castoro
    module Peer
      c = Configurations::Pgctl
      c.file = '../../etc/castoro/pgctl.conf-sample-ja.conf'
      p c.instance
    end
  end
end

