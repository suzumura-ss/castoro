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

require "rubygems"

require "castoro-manipulator"

require "fileutils"

module Castoro
  class Manipulator

    class Command

      FILE_PERMISSION_MASK = 0666

      def self.new_recursive_mkdir source, mode, user, group
        # The instance is decorate to
        # the reverse order of the file operation.
        
        # path normalize.
        source = $1 if source =~ /^(.*)\/$/
        elems = source.split(File::SEPARATOR)

        cmd = Command.new
        until elems.empty?
          p = File.join *elems
          if p != "" and !File.directory?(p)
            cmd = Command::Chmod.new(cmd, p, mode)
            cmd = Command::Chown.new(cmd, p, user, group)
            cmd = Command::Mkdir.new(cmd, p)
          end
          elems.pop
        end
        cmd
      end

      def self.new_recursive_move source, dest, mode, user, group
        # The instance is decorate to
        # the reverse order of the file operation.
        
        # path normalize.
        source = $1 if source =~ /^(.*)\/$/
        dest   = $1 if dest   =~ /^(.*)\/$/

        elems = File.dirname(dest).split(File::SEPARATOR)

        cmd = Command.new
        Dir[File.join(source, "*")].each { |file|
          f = File.join(dest, File.basename(file))
          cmd = Command::Chmod.new(cmd, f, mode & FILE_PERMISSION_MASK)
          cmd = Command::Chown.new(cmd, f, user, group)
        }
        cmd = Command::Chmod.new(cmd, dest, mode)
        cmd = Command::Chown.new(cmd, dest, user, group)
        cmd = Command::Move.new(cmd, source, dest)
        until elems.empty?
          p = File.join *elems
          if p != "" and !File.directory?(p)
            cmd = Command::Chmod.new(cmd, p, mode)
            cmd = Command::Chown.new(cmd, p, user, group)
            cmd = Command::Mkdir.new(cmd, p)
          end
          elems.pop
        end
        cmd
      end

      def initialize
        @command = nil
      end

      def invoke
        execute
        begin
          @command.invoke if @command
        rescue
          rollback
          raise
        end
      end

      private

      def execute; end
      def rollback; end
    end

    ##
    # Mkdir.
    #
    class Command::Mkdir < Command
      def initialize command, source
        @command = command
        @source = source
      end

      private

      def execute
        raise ManipulatorError, "directory already exist - #{@source}" if File.directory?(@source)
        FileUtils.mkdir @source
      end

      def rollback
        FileUtils.rmdir @source
      end
    end

    ##
    # Move.
    #
    class Command::Move < Command
      def initialize command, source, dest
        @command = command
        @source, @dest = source, dest
      end

      private

      def execute
        raise ManipulatorError, "directory not found - #{@source}" unless File.directory?(@source)
        raise ManipulatorError, "directory already exist - #{@dest}" if File.directory?(@dest)
        FileUtils.mv @source, @dest
      end

      def rollback
        FileUtils.mv @dest, @source
      end
    end

    ##
    # Chown.
    #
    class Command::Chown < Command
      def initialize command, source, user, group
        @command = command
        @source, @user, @group = source, user, group
      end

      def execute
        raise ManipulatorError, "directory or file not found - #{@source}" unless File.exist?(@source)
        s = File.stat(@source)
        @org_uid, @org_gid = s.uid, s.gid
        FileUtils.chown @user, @group, @source
      end

      def rollback
        FileUtils.chown @org_uid, @org_gid, @source
      end
    end

    ##
    # Chmod.
    #
    class Command::Chmod < Command
      def initialize command, source, mode
        @command = command
        @source, @mode = source, mode
      end

      def execute
        raise ManipulatorError, "directory or file not found - #{@source}" unless File.exist?(@source)
        s = File.stat(@source)
        @org_mode = s.mode
        File.chmod @mode, @source
      end

      def rollback
        File.chmod @org_mode, @source
      end

    end

  end
end

