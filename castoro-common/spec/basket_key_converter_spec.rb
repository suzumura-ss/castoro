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

    describe "with proper args" do
      it "should return an instance" do
        args = { "Dec40Seq" => "1-999", "Hex64Seq" => "1000-1999" }
        Castoro::BasketKeyConverter.new(args).class.should == Castoro::BasketKeyConverter
      end
    end

    describe "with an unknown module name" do
      it "should raise an ArgumentError" do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "1-999", "XXXXXXXX" => "1000-1999" )
        end.should raise_error(ArgumentError, /Unknown/)
      end
    end

    describe "with ranges that overwrap each other" do
      it "should raise an ArgumentError" do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "1-999", "Hex64Seq" => "999-1499" )
        end.should raise_error(ArgumentError, /overwrap/)
      end
    end

    describe "with a range whose starting value exceeds ending value" do
      it "should raise an ArgumentError" do
        lambda do
          Castoro::BasketKeyConverter.new( "Dec40Seq" => "2-1", "Hex64Seq" => "999-1499" )
        end.should raise_error(ArgumentError, /exceeds/)
      end
    end


    describe "with an invalid range expression" do
      it "should raise an ArgumentError" do
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

    converter = Castoro::BasketKeyConverter.new args

    samples.each do |entry|
      input, output = entry
      it "#{input} should be converted to #{output}" do
        yield converter, input, output
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
      converter.path( "/data", basket ).should == output
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

end


__END__
  samples = { 
    :string => 
    [
     [ "654321.1.1",                 "654321.1.1" ],
     [ "3210987654321.2000.1",       "3210987654321.2000.1" ],
     [ "1234567890.3333.1",          "1234567890.3333.1" ],
     [ "78901234.3333.1",            "78901234.3333.1" ],
     [ "0xaaa.1000.1",               "0x0000000000000aaa.1000.1" ],
     [ "0x0123456789ABCDEF.1000.1",  "0x0123456789abcdef.1000.1" ],
     [ "0x00fedcba98765432.1234.5",  "0x00fedcba98765432.1234.5" ],
     [ "0x6789abcdef.9999.4",        "444691369455.9999.4" ],
    ],

    :path =>
    [    
     [ "654321.1.1",                  "/data/1/baskets/a/0/000/654/654321.1.1" ],
     [ "3210987654321.2000.1",        "/data/2000/baskets/a/3210/987/654/3210987654321.2000.1" ],
     [ "1234567890.3333.1",           "/data/3333/baskets/a/1/234/567/1234567890.3333.1" ],
     [ "78901234.3333.1",             "/data/3333/baskets/a/0/078/901/78901234.3333.1" ],
     [ "0xaaa.1000.1",                "/data/1000/baskets/a/0/000/000/000/000/0000000000000aaa.1000.1" ],
     [ "0x0123456789ABCDEF.1000.1",   "/data/1000/baskets/a/0/123/456/789/abc/0123456789abcdef.1000.1" ],
     [ "0x00fedcba98765432.1234.5",   "/data/1234/baskets/a/0/0fe/dcb/a98/765/00fedcba98765432.1234.5" ],
     [ "0x6789abcdef.9999.4",         "/data/9999/baskets/a/444/691/369/444691369455.9999.4" ],
    ],

    :converter_module =>
    [
     [ "1",     Castoro::BasketKeyConverter::Module::Dec40Seq ],
     [ "2000",  Castoro::BasketKeyConverter::Module::Dec40Seq ],
     [ "3333",  Castoro::BasketKeyConverter::Module::Dec40Seq ],
     [ "3333",  Castoro::BasketKeyConverter::Module::Dec40Seq ],
     [ "1000",  Castoro::BasketKeyConverter::Module::Hex64Seq ],
     [ "1000",  Castoro::BasketKeyConverter::Module::Hex64Seq ],
     [ "1234",  Castoro::BasketKeyConverter::Module::Hex64Seq ],
     [ "9999",  Castoro::BasketKeyConverter::Module::Dec40Seq ],
    ],
  }

  [:string, :path, :converter_module].each do |method|
    describe "##{method}" do

      before(:each) do
        args = {
          "Dec40Seq" => "1-999, 2000, 3000-3999",
          "Hex64Seq" => "1000-1999",
        }
        @converter = Castoro::BasketKeyConverter.new args
      end

      samples[ method ].each do |entry|
        input, output = entry
        it "#{input} should be converted to #{output}" do
          case method
          when :path
            basket = input.to_basket
            (@converter.__send__ method, "/data", basket).should == output
          else
            basket = input.to_basket
            (@converter.__send__ method, basket).should == output
          end
        end
      end
    end

  end
end
