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
  class BasketKeyConverter

    def initialize args
      @entries = parse args
      check_overwrap @entries.keys
      @cache = Hash.new { |cache, type| examine(cache, type) }
    end

    def path base_dir, basket
      @cache[ basket.type ].path base_dir, basket
    end

    def string basket
      @cache[ basket.type ].string basket
    end

    def converter_module type
      @cache[ type ]
    end

    private

    def parse args
      Hash.new.tap do |h|
        args.each do |key, value|
          value.split(',').each do |portion|
            if portion =~ /\A\s*(\d+)(?:-(\d+))?\s*\Z/
              min = $1.to_i
              max = ($2 || $1).to_i
              min <= max or raise ArgumentError, "starting value exceeds ending value in the Type ID range: #{portion}"
              h[ min..max ] = find_module( key )
            else
              raise ArgumentError, "Invalid expression in the Type ID range: #{portion}"
            end
          end
        end
      end
    end

    def check_overwrap ranges
      loop do
        a = ranges.shift
        break if ranges.empty?
        ranges.each do |b|
          if a.cover? b.min or a.cover? b.max
            raise ArgumentError, "Two ranges overwrap each other: #{a} and #{b}"
          end
        end
      end
    end

    # if the cache misses, examine the type and assign it
    def examine cache, type
      range, converter = @entries.find { |key, value| key.cover? type }
      cache[ type ] = converter || Module::Dec40Seq  # if the type does not match, use the fallback module
    end

    def find_module name
      Module.const_get(name)
    rescue
      raise ArgumentError, "Unknown basket key converter module name: #{name}"
    end

    module Module
      module Dec40Seq
        def path base_dir, basket
          "#{base_dir}/#{basket.type}/baskets/a/#{mid(basket)}/#{dir(basket)}"
        end

        def string basket
          sprintf '%d.%d.%d', basket.content, basket.type, basket.revision
        end

        #        654321 =>    0/000/654
        # 3210987654321 => 3210/987/654
        def mid basket
          n = basket.content / 1000
          n, c = n.divmod 1000
          a, b = n.divmod 1000
          sprintf '%d/%03d/%03d', a, b, c
        end

        alias dir string

        module_function :path, :string, :mid, :dir
      end

      module Hex64Seq
        def path base_dir, basket
          "#{base_dir}/#{basket.type}/baskets/a/#{mid(basket)}/#{dir(basket)}"
        end

        def string basket
          sprintf '0x%016x.%d.%d', basket.content, basket.type, basket.revision
        end

        # 0x0123456789abcdef => 0123/456/789/abc
        def mid basket
          e = basket.content >> 12
          d = e >> 12
          c = d >> 12
          b = c >> 12
          a = b >> 12
          sprintf '%01x/%03x/%03x/%03x/%03x', (a & 0xf), (b & 0xfff), (c & 0xfff), (d & 0xfff), (e & 0xfff)
        end

        def dir basket
          sprintf '%016x.%d.%d', basket.content, basket.type, basket.revision
        end

        module_function :path, :string, :mid, :dir
      end
    end

  end
end
