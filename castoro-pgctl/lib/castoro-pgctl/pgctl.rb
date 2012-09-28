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
      end

      def usage
        x = @program_name
        puts <<-EOT
#{@program_name} - Castoro Peer Group Control command - Version #{PKG_VERSION}"

 usage: #{x} [global options] subcommand [hostname|groupname]...

  global options:
   -h, --help     prints this help message and exit.
   -d, --debug    this command runs with debug messages being printed.
   -V, --version  shows a version number of this command.
   -c file, --configuration-file=file  specifies a configuration file of pgctl.
                  default: #{Configurations::Pgctl::DEFAULT_FILE}
   -p file, --peer-configuration-file=file  specifies a configuration file of peer.
                  default: #{Configurations::Peer::DEFAULT_FILE}

  subcommands:
   #{x}  help
    help     prints this help message and exit.

   #{x} [global options]  list|passwd
   #{x} [global options]  list|ps|status|date|remains  hostname|groupname...
    list     lists peer groups
    ps       lists the deamon processes in a 'ps -ef' format
    status   shows the status of the deamon processes on the every host
    date     retrieves system date of each host
    remains  lists remains of temporary basket directories and replications
    passwd   sets a password for the critical sub commands

   #{x} [global options]  gstart|gstop  groupname...
    gstart   starts deamon processes of every host in the specified peer group
    gstop    stops  daemon processes of every host in the specified peer group

   #{x} [global options]  enable|disable|start|stop  hostname...
    enable   starts daemon processes of the only target peer host
    disable  stops  daemon processes of the only target peer host
    start    starts daemon processes of the specified peer host and leave them offline
    stop     stops  daemon processes of the specified peer host by force without any check

 examples:
   #{x} list
        shows a list of peer groups
       e.g. \"#{x} list G00\" shows:
            G00 = peer101 peer102 peer103

   #{x} passwd
        To set a new password:
          Setting a password of the command pgctl.
          New pgctl password: xxxxx 
          Retype new pgctl password: xxxxx
        
        To change a password:
          Changing a password of the command pgctl.
          (current) pgctl password: xxxxx
          New pgctl password: yyyyy
          Retype new pgctl password: yyyyy
        
        To empty a password:
          Changing a password of the command pgctl.
          (current) pgctl password: yyyyy
          New pgctl password: (just hit the enter key)
          Retype new pgctl password: (just hit the enter key again)

   #{x} ps peer101
        shows the daemon processes of peer101.

   #{x} ps G00
        shows the daemon processes of peer101, peer102, and peer103.

   #{x} status peer101 peer102
        shows the status of peer101 and peer102.

   #{x} status G00
        shows the status of peer101, peer102, and peer103.

   #{x} disable peer101
        turns peer101, peer102, and peer103 readonly,
        and then stops peer101.

   #{x} enable peer101
        if peer101 has stopped, starts it, and then
        turns peer101, peer102, and peer103 online.
        Both peer102 and peer103 have to be running.

   #{x} gstop G00
        gracefully stops peer101 peer102, and peer103.

   #{x} gstart G00
        starts peer101 peer102, and peer103, and then turn them online.

   #{x} start peer101
        starts peer101, and then leave it offline.

   #{x} stop peer101
        stops peer101 by force without any check

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
        c = case x
            when 'help'     ; usage ; Process.exit 0
            when 'list'     ; SubCommand::List
            when 'date'     ; SubCommand::Date
            when 'ps'       ; SubCommand::Ps
            when 'status'   ; SubCommand::Status
            when 'remains'  ; SubCommand::Remains
            when 'gstart'   ; SubCommand::Gstart
            when 'gstop'    ; SubCommand::Gstop
            when 'enable'   ; SubCommand::Enable
            when 'disable'  ; SubCommand::Disable
            when 'start'    ; SubCommand::Start
            when 'stop'     ; SubCommand::Stop
            when 'passwd'   ; SubCommand::Passwd
            else
              raise CommandLineArgumentError, "Unknown sub-command: #{x}"
            end
        c.new
      end

      def parse
        parse_options
        parse_sub_command
      rescue CommandLineArgumentError, GetoptLong::InvalidOption => e
        STDERR.puts "#{@program_name}: #{e.message}"
        puts ""
        puts "Use \"#{@program_name} -h\" to see the help messages"
        Process.exit 1
      end

      def run
        $StartTime = Time.new  # the current time
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
          Log.stop
          Process.exit 2
        end
      rescue Failure::Base => e
        puts "\nOne or more errors occurred:"
        m = e.message.gsub( %r/\n/, "\n " )
        puts " #{m}"
        puts "\nFailed:\n #{@program_name} #{args}"
        Log.stop
        Process.exit 3
      end
    end

  end
end

if $0 == __FILE__
  Castoro::Peer::PgctlMain.instance.run
end
