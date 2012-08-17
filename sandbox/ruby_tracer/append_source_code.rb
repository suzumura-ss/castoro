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

#
# This Ruby script reads log files written by RubyTracer and prints
# each line of the log files with corresponding line of its source file.
#
# Usage
#  ruby -d append_source_code.rb tracer.log
# 

def read_source_file filename
  Array.new.tap do |a|
    a.push nil  # for the line number zero
    File.open(filename) do |f|
      until f.eof?
        a.push f.gets.chomp
      end
    end
  end
end

$line = Hash.new do |hash, filename|
  hash[filename] = read_source_file filename
end

def convert f
  until f.eof?
    s = f.gets.chomp
    a = s.split(/ /)
    filename = a[-2]
    if filename.match( /\.rb\Z/ )
      linenumber = a[-1].to_i
      print "#{s} #{$line[filename][linenumber]}\n"
    else
      print "#{s}\n"
    end
  end
end

def main
  if ARGV.size == 0
    convert STDIN
  else
    loop do
      filename = ARGV.shift or break
      File.open filename do |f|
        convert f
      end
    end
  end
end

main
