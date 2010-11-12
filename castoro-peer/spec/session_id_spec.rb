#
#   Cloneright 2010 Ricoh Company, Ltd.
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

require File.dirname(__FILE__) + '/spec_helper.rb'

require 'castoro-peer/session_id'

describe Castoro::SessionIdGenerator.new do
  before do
    Time.stub!(:now).and_return(12345)

    @gen = ::Castoro::SessionIdGenerator.new
  end

  it "should return unique number." do
    @gen.generate.should == 1234500000001
    @gen.generate.should == 1234500000002
    @gen.generate.should == 1234500000003
    @gen.generate.should == 1234500000004
    @gen.generate.should == 1234500000005
    @gen.generate.should == 1234500000006
    @gen.generate.should == 1234500000007
    @gen.generate.should == 1234500000008
    @gen.generate.should == 1234500000009
    @gen.generate.should == 1234500000010
  end

  it "should return unique number." do
    values  = []
    threads = []

    10.times {
      threads << Thread.fork {
        100.times { values << @gen.generate }
      }
    }

    threads.each { |t| t.join }
    values.size.should == (10 * 100)
    values.size.should == values.uniq.size
  end

end

