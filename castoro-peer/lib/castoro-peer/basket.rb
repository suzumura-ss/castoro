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

require 'castoro-common/basket_key_converter'

module Castoro
  module Peer

    class Basket
      attr_reader :content, :type, :revision

      def self.setup ranges, base_dir
        @@base_dir = base_dir
        @@converter = BasketKeyConverter.new( ranges, { :base_dir => base_dir } )
      end

      def self.new_from_text( s )
        c, t, r = s.split( '.' )
        new( c.to_i, t.to_i, r.to_i )
      end

      def initialize content, type, revision
        @content, @type, @revision = content, type, revision
        @converter = @@converter.converter_module type
      end

      def to_s
        defined?(@s) ? @s : @s = @converter.string(self)
      end

      def path_w
        defined?(@w) ? @w : @w = create_temp_path("baskets/w")
      end

      def path_r
        defined?(@r) ? @r : @r = create_temp_path("baskets/r")
      end

      def path_a
        defined?(@a) ? @a : @a = @converter.path(self)
      end

      def path_d
        defined?(@d) ? @d : @d = create_temp_path("baskets/d")
      end

      def path_c
        defined?(@c) ? @c : @c = create_temp_path("offline/canceled")
      end

      def path_c_with_hint path
        path.match( /\/([^\/]+)$/ )
        @c = create_full_path("offline/canceled", $1)
        if ( File.exist? @c )
          @c = mktemp( @c )
        end
        @c
      end

      private

      def create_full_path part, dir
        unless defined? @time
          @time = Time.now.strftime("%Y%m%dT%H")
        end
        "#{@@base_dir}/#{@type}/#{part}/#{@time}/#{dir}"
      end

      def create_temp_path part
        unless defined? @dir
          @dir = @converter.dir self
        end
        mktemp create_full_path(part, @dir)
      end

      def mktemp path
        t = Time.new
        body = "#{path}.#{t.strftime('%Y%m%dT%H%M%S')}.#{'%03d' % (t.usec / 1000)}"
        offset = 1
        big_number = Process.pid * Thread.current.object_id
        begin
          number = big_number / offset % 1000000
          candidate = "#{body}.#{'%06d' % number}"
          return candidate unless File.exist? candidate
          offset = offset * 10
        end until 1000000 < offset
        raise InternalServerError, "mktemp failed: #{path} for #{to_s}"
      end
    end

  end
end


