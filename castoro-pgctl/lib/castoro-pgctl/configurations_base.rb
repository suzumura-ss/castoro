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

require 'castoro-pgctl/exceptions'

module Castoro
  module Peer

    module Configurations
      class Base
        def initialize
          @file = get_filename
          c = get_configuration_file_instance @file  # defined in a subclass
          c.load
          c.validate
          @entries = c.entries
          define_attr_readers @entries
        end

        private

        def get_filename
          file = configuration_file  # defined in a subclass
          file = "#{Dir.getwd}/#{file}" unless file.match(/\A\//)
          File.exist? file or raise ConfigurationError, "Configuration file does not exist: #{file}"
          file
        end

        def define_attr_readers entries
          entries.map do |item, value|
            self.class.class_eval do
              if method_defined? item
                remove_method item 
              end
              define_method( item ) do
                value
              end
            end
          end
        end
      end


      class ConfigurationFileBase
        def initialize file
          @file = file
          @global = nil
          @services = []
        end

        def load
          # print caller.join("\n")

          @global = get_global_section_instance  # defined in a subclass
          @section = nil  # section will hold a temporal data
          File.open( @file , "r:binary" ) do |f|  # use a binary mode to accept UTF-8
            begin
              while line = f.gets do
                interprete line
              end
            rescue NameError, ArgumentError => e
              raise ConfigurationError, "#{e.message}: #{@file}:#{$.}: #{line.chomp}"
            end
          end
        end

        def validate
          @global.validate
          @services.map { |s| s.validate }
        end

        def entries
          @global.data.dup
        end

        private

        def interprete line
          debug = false  # turn on if you will need debug messages from this method

          case line

          when /\A[#;]/, /\A\s*\Z/  # Comment
            return

          when /\A\s*\[\s*(\w+)\s*\]\s*\Z/  # Section header
            print "SECTION: #{$1}\n" if debug
            case $1
            when 'global'  ; @section = @global
            when 'service' ; @services.push( @section = get_service_section_instance )  # defined in a subclass
            else ; raise NameError, "Unknown section name"
            end

          when /\A\s*(\w+)\s+(.*?)\s*\Z/  # Parameter
            print "PARAMETER: #{$1} #{$2}\n" if debug
            @section = @global if @section.nil?  # use global if it is not specified to support peer.conf in castoro-1 format
            @section.register $1.to_sym, $2

          else
            raise ArgumentError, "Invalid line"

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
          ( necessity, type, subtype = @entries[ key ] ) or raise NameError, "Unknown parameter"
          @data[ key ] = case type 
                         when :string
                           case subtype
                           when :path
                             File.exist?( value ) or raise NameError, "The path does not exist"
                           when :shell_escape
                             value.match( %r(\A[a-zA-Z0-9_ /-]+\Z) ) or raise ArgumentError, "Non-alphanumeric letter is included: #{command}"
                           end
                           value
                         when :number  # positive integer number only
                           value.match( /\A\d+\Z/ ) or raise ArgumentError, "Invalid number"
                           value.to_i
                         when :octal   # deal it as a string. ex. "0777"
                           value.match( /\A0\d+\Z/ ) or raise ArgumentError, "Invalid octal number"
                           value.oct
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
    end

  end
end
