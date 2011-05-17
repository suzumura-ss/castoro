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

require "fileutils"
require "pathname"

module Castoro #:nodoc:
  module Manipulator #:nodoc:

    ##
    # executor for file operation.
    #
    class Executor

      DEFAULT_OPTIONS = {
        :base_directory => "/expdsk",
        :directory_mode_mask => 0777,
        :file_mode_mask => 0666,
      }.freeze

      ##
      # initialize.
      #
      # === Args
      #
      # +logger+::
      #   the logger.
      # +options+::
      #   executor options.
      #
      # Valid options for +options+ are:
      #
      # :base_directory::
      #     directory for base.
      #
      def initialize logger, options = {}
        @logger = logger
        @options = DEFAULT_OPTIONS.merge(
          options.inject({}) { |ret, (k, v)|
            new_key = k.kind_of?(String) ? k.to_sym : k
            ret[new_key] = v
            ret
          }
        ).freeze
        freeze
      end

      ##
      # make directory.
      #
      # === Args
      #
      # +mode+::
      #   file mode. ex.) 0755
      # +user+::
      #   name for file owner
      # +group+::
      #   name for file owner group
      # +dir+::
      #   target directory fullpath.
      #
      def mkdir mode, user, group, dir
        raise ManipulatorError, "relative path cannot set to be dir." if     Pathname.new(dir).relative?
        raise ManipulatorError, "Invalid directory - #{dir}"          unless dir =~ /^#{@options[:base_directory]}.*$/
        raise ManipulatorError, "directory already exist."            if     File.exist? dir

        # path normalize.
        dir = $1 if dir =~ /^(.*)\/$/

        @logger.info { "MKDIR #{mode},#{user},#{group},#{dir}" }

        # make directory.
        make_parent_dir(mode, user, group, File.dirname(dir)) {
          begin
            Dir.mkdir dir
            FileUtils.chmod mode, dir
            FileUtils.chown user, group, dir
          rescue
            FileUtils.remove_entry_secure dir
            raise
          end
        }

        nil
      end

      ##
      # move directory.
      #
      # === Args
      #
      # +mode+::
      #   file mode. ex.) 0755
      # +user+::
      #   name for file owner
      # +group+::
      #   name for file owner group
      # +source+::
      #   source directory fullpath.
      # +dest+::
      #   target direcotry fullpath.
      #
      def move mode, user, group, source, dest
        raise ManipulatorError, "relative path cannot set to be source." if     Pathname.new(source).relative?
        raise ManipulatorError, "Invalid source directory - #{source}"   unless source =~ /^#{@options[:base_directory]}.*$/
        raise ManipulatorError, "relative path cannot set to be dest."   if     Pathname.new(dest).relative?
        raise ManipulatorError, "Invalid dest directory - #{dest}"       unless dest =~ /^#{@options[:base_directory]}.*$/
        raise ManipulatorError, "source path not exist."                 unless File.exist? source
        raise ManipulatorError, "dest path already exist."               if     File.exist? dest

        # path normalize.
        source = $1 if source =~ /^(.*)\/$/
        dest   = $1 if dest   =~ /^(.*)\/$/

        @logger.info { "MOVE  #{mode},#{user},#{group},#{source},#{dest}" }

        # make dest parent directory.
        make_parent_dir(mode, user, group, File.dirname(dest)) {

          move_file(source, dest) {

            stats = {}
            Dir[dest, File.join(dest, "**/*")].each { |f| stats[f] = File.stat(f) }

            chmod(stats, mode, dest) {
              chown(stats, user, group, dest)
            }
          }
        }

        nil
      end

      private

      ##
      # interal for make directory.
      #
      # === Args
      #
      # +mode+::
      #   file mode. ex.) 0755
      # +user+::
      #   name for file owner
      # +group+::
      #   name for file owner group
      # +dir+::
      #   target directory fullpath.
      #
      def make_parent_dir mode, user, group, dir
        elems       = dir.split(File::SEPARATOR)
        path        = "/"
        nothing_dir = nil

        until (elems.empty? or nothing_dir)
          path = File.join(path, elems.shift)
          nothing_dir = path unless File.exist? path
        end

        FileUtils.mkdir_p dir
        FileUtils.chmod_R mode, nothing_dir if nothing_dir
        FileUtils.chown_R user, group, nothing_dir if nothing_dir

        yield if block_given?

      rescue
        FileUtils.remove_entry_secure nothing_dir if nothing_dir
        raise
      end

      def move_file src, dest #:nodoc:

        FileUtils.move src, dest, :secure => true

        yield if block_given?

      rescue
        FileUtils.move dest, src, :secure => true
        raise
      end

      def chmod stats, mode, dir #:nodoc:

        dir_mode  = mode & @options[:directory_mode_mask].to_i
        file_mode = mode & @options[:file_mode_mask].to_i
        FileUtils.chmod(dir_mode , Dir[dir, File.join(dir, "**/*")].select { |f| File.directory?(f) })
        FileUtils.chmod(file_mode, Dir[dir, File.join(dir, "**/*")].select { |f| File.file?(f)      })

        yield if block_given?

      rescue
        stats.each { |k, v| FileUtils.chmod v.mode, k }
        raise
      end

      def chown stats, user, group, dir #:nodoc:

        FileUtils.chown_R(user, group, dir)

        yield if block_given?

      rescue
        stats.each { |k, v| FileUtils.chown v.uid, v.gid, k }
        raise
      end

    end

  end
end

