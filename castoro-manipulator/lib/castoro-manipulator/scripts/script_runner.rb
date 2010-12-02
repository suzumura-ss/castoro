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

require "castoro-manipulator"

require "erb"
require "logger"
require "yaml"
require "fileutils"
require "timeout"
require "etc"

module Castoro
  module Manipulator

    class ScriptRunner
      @@stop_timeout = 10

      def self.start options
        STDERR.puts "*** Starting Castoro::Manipulator daemon..."

        config = YAML::load(ERB.new(IO.read(options[:conf])).result)

        raise "Envorinment not found - #{options[:env]}" unless config.include?(options[:env])
        config = config[options[:env]]

        user = config["user"] || Manipulator::DEFAULT_SETTINGS["user"]

        uid = begin
                user.kind_of?(Integer) ? Etc.getpwuid(user.to_i).uid : Etc.getpwnam(user.to_s).uid
              rescue ArgumentError
                raise "can't find user for #{user}"
              end

#        raise "Don't run as root user." if uid == 0

        Process::Sys.seteuid(uid)

        if options[:daemon]
          raise "PID file already exists - #{options[:pid]}" if File.exist?(options[:pid])

          # create logger.
          logger = if config["logger"]
                     eval(config["logger"].to_s).call(options[:log])
                   else
                     eval(Manipulator::DEFAULT_SETTINGS["logger"]).call(options[:log])
                   end

          # daemonize and create pidfile.
          FileUtils.touch options[:pid]
          fork {
            Process.setsid
            fork {
              Dir.chdir("/")
              STDIN.reopen  "/dev/null", "r+"
              STDOUT.reopen "/dev/null", "a"
              STDERR.reopen "/dev/null", "a"

              dispose_proc = Proc.new { File.unlink options[:pid] if File.exist?(options[:pid]) }

              # pidfile.
              File.open(options[:pid], "w") { |f| f.puts $$ } if options[:pid]
              Kernel.at_exit &dispose_proc

              begin
                manipulator = Castoro::Manipulator::Manipulator.new(config, logger)
                set_signalhandler manipulator, &dispose_proc
                manipulator.start
                while manipulator.alive?; sleep 3; end
                sleep
              rescue => e
                logger.error { e.message }
                logger.debug { e.backtrace.join("\n\t") }
                exit 1
              end
            }
          }
        else
          manipulator = Castoro::Manipulator::Manipulator.new(config, Logger.new(STDOUT))
          set_signalhandler manipulator
          manipulator.start
          while manipulator.alive?; sleep 3; end
        end

      rescue => e
        STDERR.puts "--- Castoro::Manipulator error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit 1

      ensure
        STDERR.puts "*** done."
      end

      def self.stop options
        STDERR.puts "*** Stopping Castoro::Manipulator daemon..."
        raise "PID file not found - #{options[:pid]}" unless File.exist?(options[:pid])
        timeout(@@stop_timeout) {
          send_signal(options[:pid], options[:force] ? :TERM : :HUP)
          while File.exist?(options[:pid]); end
        }

      rescue => e
        STDERR.puts "--- Castoro::Manipulator error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit 1

      ensure
        STDERR.puts "*** done."
      end

      def self.setup options
        STDERR.puts "*** Setting Castoro::Manipulator config..."
        STDERR.puts "--- setup configuration file to #{options[:conf]}..."

        if File.exist?(options[:conf])
          raise "Config file already exists - #{options[:conf]}" unless options[:force]
        end

        confdir = File.dirname(options[:conf])
        FileUtils.mkdir_p confdir unless File.directory?(confdir)
        open(options[:conf], "w") { |f|
          f.puts Manipulator::SETTING_TEMPLATE
        }
      
      rescue => e
        STDERR.puts "--- Castoro::Manipulator error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit 1

      rescue
        STDERR.puts "*** done."
      end

      private

      def self.set_signalhandler manipulator
        stopping = false
        [:INT, :HUP, :TERM].each { |sig|
          trap(sig) { |s|
            unless stopping
              stopping = true
              manipulator.stop(s == :TERM)
              yield if block_given?
              exit! 0
            end
          }
        }
      end

      def self.send_signal pid_file, signal
        # SIGINT signal is sent to dispatcher daemon(s9.
        pid = File.open(pid_file, "r") { |f| f.read }.to_i

        Process.kill(signal, pid)
        Process.waitpid2(pid) rescue nil
      end

    end

  end
end

