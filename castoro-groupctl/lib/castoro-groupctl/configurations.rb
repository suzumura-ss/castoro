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
require 'yaml'
require 'json'
require 'castoro-groupctl/log'
require 'castoro-groupctl/errors'

module Castoro
  module Peer

    class Configurations
      include Singleton

      CONFIGURATION_FILE_CANDIDATES = [ '/etc/castoro/groupctl.conf' ]

      def self.file= file
        @@initial_file = file
      end
          
      def default_configuration_file
        files = CONFIGURATION_FILE_CANDIDATES
        files.map do |f|
          return f if File.exist? f
        end
        raise StandardError, "No configuration file is found. Default files are #{files.join(' ')}"
      end

      def initialize
        @mutex = Mutex.new
        @entries = nil
        @file = @@initial_file if defined? @@initial_file
        @file = default_configuration_file if @file.nil?
        @config_file = ConfigurationFile.new
        self.load
      end

      def load( file = nil )
        @mutex.synchronize {
          f = file || @file
          f = "#{Dir.getwd}/#{f}" unless f.match(/\A\//)
          # Log.notice( "Loading configration file: #{f}" )
          # print "#{caller.join("\n")}\n"
          @entries = @config_file.load( f )  # exceptions might be raised
          @file = f
          # Log.notice( "Configuration data in #{@file}: #{@entries.inspect}" )
          define_readers()
          @entries
        }
      end

      private

      def define_readers
        @entries.keys.map do |item|
          Configurations.class_eval do
            if ( method_defined? item )
              remove_method( item )
            end
            define_method( item ) do
              @mutex.synchronize do
                @entries[ item ]
              end
            end
          end
        end
      end
    end


    class ConfigurationFile
      def initialize
        @global = nil
        @services = []
      end

      def load file
        load_configuration_file file
        @global.validate
        @data = @global.data.dup
        @data
      rescue => e
        raise ConfigurationError, "#{e.class} \"#{e.message}\" #{e.backtrace.slice(0,5).inspect}"
      end

      private

      def load_configuration_file file
        section = nil
        File.open( file , "r:binary" ) do |f|  # Any character encoding such as UTF-8 is accepted
          begin
            while line = f.gets do
              case line
              when /\A[#;]/, /\A\s*\Z/  # Comment
                next
              when /\A\s*(\w+)\s+(.*?)\s*\Z/  # Parameter
                # print "PARAMETER: #{$1} #{$2}\n"
                section or raise ArgumentError, "Section is not yet specified"
                section.register $1.to_sym, $2
              when /\A\s*\[\s*(\w+)\s*\]\s*\Z/  # Section header
                # print "SECTION: #{$1}\n"
                case $1
                when 'global'  ; @global = section = GlobalSection.new
                when 'service' ; @services.push( section = ServiceSection.new )
                else ; raise NameError, "Unknown section name"
                end
              else
                raise ArgumentError, "Invalid line"
              end
            end
          rescue => e
            raise ConfigurationError, "#{e}: #{file}:#{$.}: #{line.chomp}"
          end
        end
      end


      class Section
        attr_reader :data

        def initialize entries
          @entries = entries
          @data = {}
        end

        def register key, value
          ( necessity, type, path = @entries[ key ] ) or raise NameError, "Unknown parameter"
          @data[ key ] = case type 
                         when :string
                           if path
                             File.exist?( value ) or raise NameError, "The path does not exist"
                           end
                           value
                         when :number  # positive integer number only
                           value.match( /\A\d+\Z/ ) or raise ArgumentError, "Invalid number"
                           value.to_i
                         when :octal   # deal it as a string. ex. "0777"
                           value.match( /\A0\d+\Z/ ) or raise ArgumentError, "Invalid octal number"
                           value
                         when :boolean
                           evaluate_boolean value
                         end
        end
        
        def validate
          @entries.each do |key, spec|
            if :mandatory == spec[0]
              @data.has_key?( key ) or raise ArgumentError, "#{key} is not specified"
            end
          end
        end

        def []( key )
          @data[ key ]
        end
        
        private

        def evaluate_boolean value
          return true  if %w( yes true on  ).include? value
          return false if %w( no false off ).include? value
          raise ArgumentError, "Invalid boolean"
        end
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
                :cstartd_ps_options                         => [ :mandatory, :string ],
                )
        end
      end


      class ServiceSection < Section
      end
    end

  end
end
