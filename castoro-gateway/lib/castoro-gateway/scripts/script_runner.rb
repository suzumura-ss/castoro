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

require "castoro-gateway"

require "erb"
require "logger"
require "yaml"
require "fileutils"
require "timeout"
require "etc"
require "drb/drb"

module Castoro
  class Gateway

    class ScriptRunner
      @@stop_timeout = 10
  
      def self.start options
        STDERR.puts "*** Starting Castoro::Gateway..."
  
        config = YAML::load(ERB.new(IO.read(options[:conf])).result)
  
        raise "Environment not found - #{options[:env]}" unless config.include?(options[:env])
        config = config[options[:env]]

        [*config["require"]].each { |r| require r } if config["require"]

        group = config["group"] || Gateway::Configuration::COMMON_SETTINGS["group"]
        if group
          gid = begin
                  group.kind_of?(Integer) ? Etc.getgrgid(group.to_i).gid : Etc.getgrnam(group.to_s).gid
                rescue ArgumentError
                  raise "con't find group for #{group}"
                end
          Process::Sys.setegid(gid)
        end
  
        user = config["user"] || Gateway::Configuration::COMMON_SETTINGS["user"]
        
        uid = begin
                user.kind_of?(Integer) ? Etc.getpwuid(user.to_i).uid : Etc.getpwnam(user.to_s).uid 
              rescue ArgumentError
                raise "can't find user for #{user}"
              end
  
        raise "Dont't run as root user." if uid == 0
  
        Process::Sys.seteuid(uid)
 
        # create logger. 
        logger = if options[:daemon]
                   if config["logger"]
                     eval(config["logger"].to_s).call(options[:log])
                   else
                     eval(Gateway::Configuration::COMMON_SETTINGS["logger"]).call(options[:log])
                   end
                 else
                   Logger.new(STDOUT)
                 end

        gateway = Gateway.new config, logger

        if options[:daemon]
          raise "PID file already exists - #{options[:pid]}" if File.exist?(options[:pid])
  
          # daemonize and create pidfile.
          FileUtils.touch options[:pid]
          fork {
            Process.setsid
            fork {
              begin
                Dir.chdir("/")
                STDIN.reopen "/dev/null", "r+"
                STDOUT.reopen "/dev/null", "a"
                STDERR.reopen "/dev/null", "a"

                init_gateway gateway, options[:pid]
                sleep
              rescue => e
                FileUtils.rm pid_file if options[:pid] and File.exist? options[:pid]
              end
            }
          }
        else
          init_gateway gateway
        end
  
      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)
  
      ensure
        STDERR.puts "*** done."
      end
  
      def self.stop options
        STDERR.puts "*** Stopping Castoro::Gateway daemon..."
        raise "PID file not found - #{options[:pid]}" unless File.exist?(options[:pid])
        timeout(@@stop_timeout) {
          send_signal(options[:pid], options[:force] ? :TERM : :HUP)
          while File.exist?(options[:pid]) ; end
        }
  
      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)
        
      ensure
        STDERR.puts "*** done."
      end
  
      def self.setup options
        STDERR.puts "*** Setup Castoro::Gateway daemon..."
        STDERR.puts "--- setup configuration file to #{options[:conf]}..."
  
        if File.exist?(options[:conf])
          raise "Config file already exists - #{options[:conf]}" unless options[:force]
        end
  
        confdir = File.dirname(options[:conf])
        FileUtils.mkdir_p confdir unless File.directory?(confdir)
        open(options[:conf], "w") { |f|
          f.puts Gateway::Configuration.setting_template(options[:type] || "original")
        }
        
      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)
  
      ensure
        STDERR.puts "*** done."
      end
  
      def self.status options
        ret = connect_to_console(options[:ip].to_s, options[:port].to_i) { |obj|
          obj.status
        }

        if ret.length > 0 then
          # When ret.length is 0, ret.keys.max{}.length generates an error for keys.max is return nil. 
          width  = ret.keys.max { |x, y| x.length <=> y.length }.length
          key_format = "%-#{width}s"
          ret.each { |k, v|
            STDOUT.puts "#{key_format % k} : #{v}"
          }
        end
      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)
      end
  
      def self.peers_status options
        ret = connect_to_console(options[:ip].to_s, options[:port].to_i) { |obj|
          obj.peers_status
        }
  
        ret.each { |k, v|
          STDOUT.puts "#{k}:#{v}\n"
        }
      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)
      end

      def self.dump options
        connect_to_console(options[:ip].to_s, options[:port].to_i) { |obj| obj.dump STDOUT }
  
      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)
      end

      def self.purge options
        STDERR.puts "*** Purge Castoro::Gateway..."

        results = connect_to_console(options[:ip].to_s, options[:port].to_i) { |obj|
          obj.purge *ARGV 
         }

        STDERR.puts "--- purge completed"
        results.each { |k,v|
          STDERR.puts "      #{k} - #{v} baskets."
        }

      rescue => e
        STDERR.puts "--- Castoro::Gateway error! - #{e.message}"
        STDERR.puts e.backtrace.join("\n\t") if options[:verbose]
        exit(1)

      ensure
        STDERR.puts "*** done."
      end
  
      private
  
      def self.init_gateway gateway, pid_file = nil
  
        # signal.
        stopping = false
        [:INT, :HUP, :TERM].each { |sig|
          trap(sig) { |s| # Trap a signal from send_signal()
            unless stopping
              stopping = true
              gateway.stop (s == :TERM)
              FileUtils.rm pid_file if pid_file and File.exist? pid_file
              exit! 0
            end
          }
        }
  
        # start gateway.
        gateway.start
  
        # write pid to file.
        File.open(pid_file, "w") { |f| f.puts $$ } if pid_file
  
        # sleep.
        while gateway.alive?; sleep 3; end
      end
  

      def self.send_signal pid_file, signal
        # SIGINT signal is sent to dispatcher deamon(s).l
        pid = File.open(pid_file, "r") do |f|
          f.read
        end.to_i
  
        Process.kill(signal, pid)
        Process.waitpid2(pid) rescue nil
      end

      #
      # access to druby object
      #
      def self.connect_to_console(ip, port)
        DRb.start_service
        result = nil
        DRbObject.new_with_uri("druby://#{ip}:#{port}").tap { |obj|
          result = yield obj
        }
        result
      ensure
        DRb.stop_service
      end
    end
  end
end

