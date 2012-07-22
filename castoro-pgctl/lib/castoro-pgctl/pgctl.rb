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

if $0 == __FILE__
  $LOAD_PATH.dup.each do |x|
    $LOAD_PATH.delete x if x.match %r(/gems/)
  end
  $LOAD_PATH.unshift '..'
  $LOAD_PATH.unshift '../../ext/password_reader'
end

require 'singleton'
require 'getoptlong'
require 'castoro-pgctl/version'
require 'castoro-pgctl/component'
require 'castoro-pgctl/signal_handler'
require 'castoro-pgctl/exceptions'
require 'castoro-pgctl/configurations_pgctl'
require 'castoro-pgctl/configurations_peer'
require 'castoro-pgctl/sub_command'

module Castoro
  module Peer
    
    class PgctlMain
      include Singleton

      def initialize
        @program_name = $0.sub( %r{.*/}, '' )  # name of this command
        @program_name = $0.sub( %r{\.rb\Z}, '' )
      end

      def usage
        x = @program_name
        puts <<-EOT
#{@program_name} - Castoro Peer Group Control command - Version #{PKG_VERSION}"

 usage: #{x} [global options] sub-command [host name|group name]...

  global options:
   -h, --help     prints this help message and exit.
   -d, --debug    this command runs with debug messages being printed.
   -V, --version  shows a version number of this command.
   -c file, --configuration-file=file  specifies a configuration file of pgctl.
                  default: #{Configurations::Pgctl::DEFAULT_FILE}
   -p file, --peer-configuration-file=file  specifies a configuration file of peer.
                  default: #{Configurations::Peer::DEFAULT_FILE}

  sub commands:
   list       lists peer groups
   ps         lists the deamon processes in a 'ps -ef' format
   status     shows the status of the deamon processes on the every host

   gstart     starts deamon processes of every host in the specified peer group
   gstop      stops  daemon processes of every host in the specified peer group

   enable     starts daemon processes of the only target peer host
   disable    stops  daemon processes of the only target peer host
   start      starts daemon processes of the specified peer host and leave them offline
   stop       stops  daemon processes of the specified peer host by force without any check

   passwd     sets a password for the critical sub commands

 examples:
   #{x} list
        shows a list of peer groups
       e.g. \"#{x} list G00\" shows:
            G00 = peer01 peer02 peer03

   #{x} ps peer01
        shows the daemon processes of peer01.

   #{x} ps G00
        shows the daemon processes of peer01, peer02, and peer03.

   #{x} status peer01 peer02
        shows the status of peer01 and peer02.

   #{x} status G00
        shows the status of peer01, peer02, and peer03.

   #{x} disable peer01
        turns peer01, peer02, and peer03 readonly,
        and then stops peer01.

   #{x} enable peer01
        if peer01 has stopped, starts it, and then
        turns peer01, peer02, and peer03 online.
        Both peer02 and peer03 have to be running.

   #{x} gstop G00
        gracefully stops peer01 peer02, and peer03.

   #{x} gstart G00
        starts peer01 peer02, and peer03, and then turn them online.

   #{x} start peer01
        starts peer01, and then leave it offline.

   #{x} stop peer01
        stops peer01 by force without any check

   #{x} passwd
        To set a new password:
          Setting a password of the command pgctl.
          New pgctl password: 
          Retype new pgctl password: 
        
        To change a password:
          Changing a password of the command pgctl.
          (current) pgctl password: 
          New pgctl password: 
          Retype new pgctl password: 
        
        To empty a password:
          Changing a password of the command pgctl.
          (current) pgctl password: 
          New pgctl password: (just hit an enter key)
          Retype new pgctl password: (just hit an enter key)

EOT
      end

      def parse_options
        x = GetoptLong.new(
              [ '--help',                '-h', GetoptLong::NO_ARGUMENT ],
              [ '--debug',               '-d', GetoptLong::NO_ARGUMENT ],
              [ '--version',             '-V', GetoptLong::NO_ARGUMENT ],
              [ '--configuration-file',  '-c', GetoptLong::REQUIRED_ARGUMENT ],
              [ '--peer-configuration-file',  '-p', GetoptLong::REQUIRED_ARGUMENT ],
              )

        x.each do |opt, arg|
          case opt
          when '--help'
            usage
            Process.exit 0
          when '--debug'
            $DEBUG = true
          when '--version'
            puts "#{@program_name} - Version #{PKG_VERSION}"
            Process.exit 0
          when '--configuration-file'
            Configurations::Pgctl.file = arg
          when '--peer-configuration-file'
            Configurations::Peer.file = arg
          end
        end
      end

      def parse_sub_command
        x = ARGV.shift
        x.nil? and raise CommandLineArgumentError, "No sub-command is given."
        case x
        when 'list'     ; SubCommand::List.new
        when 'ps'       ; SubCommand::Ps.new
        when 'status'   ; SubCommand::Status.new
        when 'gstart'   ; SubCommand::Gstart.new
        when 'gstop'    ; SubCommand::Gstop.new
        when 'enable'   ; SubCommand::Enable.new
        when 'disable'  ; SubCommand::Disable.new
        when 'start'    ; SubCommand::Start.new
        when 'stop'     ; SubCommand::Stop.new
        when 'passwd'   ; SubCommand::Passwd.new
        else
          raise CommandLineArgumentError, "Unknown sub-command: #{x}"
        end
      end

      def parse
        parse_options
        parse_sub_command
      rescue CommandLineArgumentError => e
        STDERR.puts "#{@program_name}: #{e.message}"
        puts ""
        puts "Use \"#{@program_name} -h\" to see the help messages"
        Process.exit 1
      end

      def run
        args = ARGV.join(' ')
        command = parse
        SignalHandler.setup

        # Singleton seems not multithread-safe
        Configurations::Pgctl.instance
        Configurations::Peer.instance

        x = true
        x = command.pre_check if command.respond_to? :pre_check
        if x
          x = command.confirm_if_the_plan_is_approved if command.respond_to? :confirm_if_the_plan_is_approved
        end
        if x
          command.authenticate if command.respond_to? :authenticate
          command.run
          SignalHandler.final_check
          command.post_check if command.respond_to? :post_check
          puts "\nSucceeded:\n #{@program_name} #{args}"
        else
          puts "\nDid nothing:\n #{@program_name} #{args}"
          Process.exit 2
        end
      rescue Failure::Base => e
        puts "\nOne or more errors occurred:"
        m = e.message.gsub( %r/\n/, "\n " )
        puts " #{m}"
        puts "\nFailed:\n #{@program_name} #{args}"
        Process.exit 3
      end
    end

  end
end

if $0 == __FILE__
  Castoro::Peer::PgctlMain.instance.run
end
