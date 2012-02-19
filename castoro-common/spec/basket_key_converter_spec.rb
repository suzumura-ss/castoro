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

require File.dirname(__FILE__) + '/spec_helper.rb'

describe Castoro::BasketKeyConverter do

  describe "#new" do

    context "with proper args" do
      it "returns an instance" do
        args = { "Dec40Seq" => "1-999", "Hex64Seq" => "1000-1999" }
        Castoro::BasketKeyConverter.new(args).class.should == Castoro::BasketKeyConverter
      end
    end

    context "with an unknown module name" do
      it "raises an ArgumentError with a message: Unknown..." do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "1-999", "XXXXXXXX" => "1000-1999" )
        end.should raise_error(ArgumentError, /Unknown/)
      end
    end

    context "with ranges that overwrap each other" do
      it "raises an ArgumentError with a message: Two ranges overwrap..." do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "1-999", "Hex64Seq" => "999-1499" )
        end.should raise_error(ArgumentError, /Two ranges overwrap/)
      end
    end

    context "with a range whose starting value exceeds ending value" do
      it "raises an ArgumentError with a message: Starting value exceeds..." do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "2-1", "Hex64Seq" => "999-1499" )
        end.should raise_error(ArgumentError, /Starting value exceeds/)
      end
    end

    context "with an invalid range expression" do
      it "raises an ArgumentError with a message: Invalid..." do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "1, 3-", "Hex64Seq" => "1000-1999" )
        end.should raise_error(ArgumentError, /Invalid/)
      end
    end

  end

  def self.converter_test samples
    args = {
      "Dec40Seq" => "1-999, 2000, 3000-3999",
      "Hex64Seq" => "1000-1999",
    }
    base_dir = "/data"

    converter = Castoro::BasketKeyConverter.new( args, { :base_dir => base_dir } )

    samples.each do |entry|
      input, output = entry
      context "with #{input}" do
        it "returns #{output}" do
          yield converter, input, output
        end
      end
    end
  end

  describe "#string" do
    samples = 
      [
       [ "654321.1.1",                 "654321.1.1" ],
       [ "3210987654321.2000.1",       "3210987654321.2000.1" ],
       [ "1234567890.3333.1",          "1234567890.3333.1" ],
       [ "78901234.3333.1",            "78901234.3333.1" ],
       [ "0xaaa.1000.1",               "0x0000000000000aaa.1000.1" ],
       [ "0x0123456789ABCDEF.1000.1",  "0x0123456789abcdef.1000.1" ],
       [ "0x00fedcba98765432.1234.5",  "0x00fedcba98765432.1234.5" ],
       [ "0x6789abcdef.9999.4",        "444691369455.9999.4" ],
      ]

    converter_test( samples ) do |converter, input, output|
      basket = input.to_basket
      converter.string(basket).should == output
    end
  end

  describe "#path" do
    samples = 
      [
       [ "654321.1.1",                  "/data/1/baskets/a/0/000/654/654321.1.1" ],
       [ "3210987654321.2000.1",        "/data/2000/baskets/a/3210/987/654/3210987654321.2000.1" ],
       [ "1234567890.3333.1",           "/data/3333/baskets/a/1/234/567/1234567890.3333.1" ],
       [ "78901234.3333.1",             "/data/3333/baskets/a/0/078/901/78901234.3333.1" ],
       [ "0xaaa.1000.1",                "/data/1000/baskets/a/0/000/000/000/000/0000000000000aaa.1000.1" ],
       [ "0x0123456789ABCDEF.1000.1",   "/data/1000/baskets/a/0/123/456/789/abc/0123456789abcdef.1000.1" ],
       [ "0x00fedcba98765432.1234.5",   "/data/1234/baskets/a/0/0fe/dcb/a98/765/00fedcba98765432.1234.5" ],
       [ "0x6789abcdef.9999.4",         "/data/9999/baskets/a/444/691/369/444691369455.9999.4" ],
      ]

    converter_test( samples ) do |converter, input, output|
      basket = input.to_basket
      converter.path( basket ).should == output
    end
  end

  describe "#converter_module" do
    samples = 
      [
       [ 1,     Castoro::BasketKeyConverter::Module::Dec40Seq ],
       [ 2000,  Castoro::BasketKeyConverter::Module::Dec40Seq ],
       [ 3333,  Castoro::BasketKeyConverter::Module::Dec40Seq ],
       [ 3333,  Castoro::BasketKeyConverter::Module::Dec40Seq ],
       [ 1000,  Castoro::BasketKeyConverter::Module::Hex64Seq ],
       [ 1000,  Castoro::BasketKeyConverter::Module::Hex64Seq ],
       [ 1234,  Castoro::BasketKeyConverter::Module::Hex64Seq ],
       [ 9999,  Castoro::BasketKeyConverter::Module::Dec40Seq ],
      ]

    converter_test( samples ) do |converter, input, output|
      converter.converter_module( input ).should == output
    end
  end

  class Converter
    attr_reader :converter

    def initialize args
      @converter = Castoro::BasketKeyConverter.new args
      a = run_thread_a
      b = run_thread_b
      a.join
      b.join
    end

    def run_thread_a
      Thread.new do
        @converter.converter_module( 100 ) == Castoro::BasketKeyConverter::Module::Dec40Seq or
          raise RuntimeError, "the conversion has been wrongly done."
      end
    end

    def run_thread_b
      Thread.new do
        @converter.converter_module( 300 ) == Castoro::BasketKeyConverter::Module::Hex64Seq or
          raise RuntimeError, "the conversion has been wrongly done."
      end
    end
  end

  describe "Multithreading environment" do
    it "Under the circumstances where two threads chase, conversion should be done correctly" do
      count = 10000

      count.times do
        Converter.new( "Dec40Seq" => "100-200", "Hex64Seq" => "300-400" )
      end

    end
  end

end
