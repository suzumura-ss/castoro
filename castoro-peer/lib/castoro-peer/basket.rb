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

module Castoro
  module Peer

    class Basket

      S_ABCENSE     = 1
      S_WORKING     = 2
      S_REPLICATING = 3
      S_ARCHIVED    = 4
      S_DELETED     = 5
      S_CONFLICT    = 6

      ##
      # basket base directory.
      #
      @@base_dir = nil

      attr_reader :content_id, :type_id, :revision_number

      def self.new_from_text( s )
        c, t, r = s.split( '.' )
        new( c.to_i, t.to_i, r.to_i )
      end

      def initialize( content_id, type_id, revision_number )
        content_id.nil? or type_id.nil? or revision_number.nil? and
          raise ArgumentError, "Basket.new( #{content_id}, #{type_id}, #{revision_number} )"
        @content_id, @type_id, @revision_number = content_id, type_id, revision_number
        @base_dir = "#{@@base_dir}/#{type_id.to_s}"

        t = Time.new
        @time_dir = t.strftime("%Y%m%dT%H")

        #        654321 =>    0/000/654
        # 3210987654321 => 3210/987/654
        n = @content_id.to_i
        a, n = n.divmod 1000000000
        b, n = n.divmod 1000000
        c    = n / 1000
        @hash_dir = sprintf('%d/%03d/%03d', a, b, c )
        @body_dir = self.to_s
      end

      def to_s
        @to_s ||= "#{@content_id}.#{@type_id}.#{@revision_number}"
      end

      def path_w
        @w ||= mktemp( "#{@base_dir}/baskets/w/#{@time_dir}/#{@body_dir}" )
      end

      def path_r
        @r ||= mktemp( "#{@base_dir}/baskets/r/#{@time_dir}/#{@body_dir}" )
      end

      def path_a
        @a ||= "#{@base_dir}/baskets/a/#{@hash_dir}/#{@body_dir}"
      end

      def path_d
        @d ||= mktemp( "#{@base_dir}/baskets/d/#{@time_dir}/#{@body_dir}" )
      end

      def path_c path = nil
        @c ||= if path.nil?
                 mktemp( "#{@base_dir}/offline/canceled/#{@time_dir}/#{@body_dir}" )
               else
                 path.match( /\/([^\/]+)$/ )
                 x = $1
                 c = "#{@base_dir}/offline/canceled/#{@time_dir}/#{x}"
                 mktemp( c ) if ( File.exist? c )
                 c
               end
      end

      private

      def mktemp( path )
        t = Time.new
        body = "#{path}.#{t.strftime('%Y%m%dT%H%M%S')}.#{'%03d' % (t.usec / 1000)}"
        offset = 1
        b = big_number  # Avoid calling a method in a loop as much as possible
        begin
          number = b / offset % 1000000
          candidate = "#{body}.#{'%06d' % number}"
          return candidate unless File.exist? candidate
          offset = offset * 10
        end until 1000000 < offset
        raise InternalServerError, "mktemp failed: #{path} for #{to_s}"
      end

      def big_number #:nodoc:
        Process.pid * Thread.current.object_id
      end
    end

  end
end

