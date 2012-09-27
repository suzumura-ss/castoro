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

describe Castoro::BasketKey do
  context "when string '123..' is specified for the #parse" do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.parse("123..")
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when string '123..1' is specified for the #parse" do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.parse("123..1")
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when string 'foo.bar.baz.qux.quux@hoge' is specified for the #parse" do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.parse("foo.bar.baz.qux.quux@hoge")
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when string '12345678901234567@5' is specified for the #parse" do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.parse("12345678901234567@5")
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when string 'foo.bar.baz.qux.quux@5' is specified for the #parse" do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.parse("foo.bar.baz.qux.quux@5")
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when string '123.4.5' is specified for the #parse" do
    before do
      @key = Castoro::BasketKey.parse "123.4.5"
    end

    it "should return Castoro::BasketKey instance" do
      @key.class.should == Castoro::BasketKey  
    end

    it "should content 123" do
      @key.content.should == 123
    end

    it "should type 4" do 
      @key.type.should == 4
    end

    it "should revision 5" do
      @key.revision.should == 5
    end

    it "should to_s '123.4.5'" do
      @key.to_s.should == "123.4.5"
    end
  end

  context "when content=-1, type=2, revision=3 is specified." do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.new(-1, 2, 3)
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when content=1, type=:hoge, revision=3 is specified." do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.new(1, :hoge, 3)
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when content=1, type=-2, revision=3 is specified." do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.new(1, -2, 3)
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when content=1, type=2, revision=-3 is specified." do
    it "should raise Castoro::BasketKeyError" do
      Proc.new {
        Castoro::BasketKey.new(1, 2, -3)
      }.should raise_error(Castoro::BasketKeyError)
    end
  end

  context "when content=123, type=0, revision=5 is specified." do
    before do
      @key = Castoro::BasketKey.new(123, 0, 5)
    end

    it "should content 123" do
      @key.content.should == 123
    end

    it "should type 0" do 
      @key.type.should == 0
    end

    it "should revision 5" do
      @key.revision.should == 5
    end

    it "should equals instance of string '123.0.5' instance that is parse result" do
      @key.should == Castoro::BasketKey.parse("123.0.5")
    end

    it "should to_s '123.0.5'" do
      @key.to_s.should == "123.0.5"
    end

    it "should type_name 'original'" do
      @key.type_name.should == "original"
    end
  end

  context "when content=123, type=1, revision=5 is specified." do
    before do
      @key = Castoro::BasketKey.new(123, 1, 5)
    end

    it "should content 123" do
      @key.content.should == 123
    end

    it "should type 1" do 
      @key.type.should == 1
    end

    it "should revision 5" do
      @key.revision.should == 5
    end

    it "should equals instance of string '123.1.5' instance that is parse result" do
      @key.should == Castoro::BasketKey.parse("123.1.5")
    end

    it "should to_s '123.1.5'" do
      @key.to_s.should == "123.1.5"
    end

    it "should type_name 'bitmap'" do
      @key.type_name.should == "bitmap"
    end
  end

  context "when content=123, type=2, revision=5 is specified." do
    before do
      @key = Castoro::BasketKey.new(123, 2, 5)
    end

    it "should content 123" do
      @key.content.should == 123
    end

    it "should type 2" do 
      @key.type.should == 2
    end

    it "should revision 5" do
      @key.revision.should == 5
    end

    it "should equals instance of string '123.2.5' instance that is parse result" do
      @key.should == Castoro::BasketKey.parse("123.2.5")
    end

    it "should to_s '123.2.5'" do
      @key.to_s.should == "123.2.5"
    end

    it "should type_name ''" do
      @key.type_name.should == ""
    end
  end

  context "when content, type and revision evaluates other instance of equivalence" do
    before do
      @key1 = Castoro::BasketKey.new(1, 2, 3)
      @key2 = Castoro::BasketKey.new(1, 2, 3)
    end

    it "evaluation result of #eql? should be true" do
      @key1.eql?(@key2).should be_true
      @key2.eql?(@key1).should be_true
    end

    it "evaluation result of == should be true" do
      (@key1 == @key2).should be_true
      (@key2 == @key1).should be_true
    end

    it "evaluation result of #equal? should be false" do
      @key1.equal?(@key2).should be_false
      @key2.equal?(@key1).should be_false
    end

    it "evaluation result of #hash should be same." do
      @key1.hash.should == @key2.hash
      @key2.hash.should == @key1.hash
    end
  end

  context "when you evaluate #eql? to a separate instance though it is equivalent" do
    it "should be true" do
      key1 = Castoro::BasketKey.new(1, 2, 3)
      key2 = Castoro::BasketKey.new(1, 2, 3)
      key1.eql?(key2).should be_true
    end
  end

  context "when :original is specified for type of constructor argument" do
    before do
      @key = Castoro::BasketKey.new(123, :original, 5)
    end

    it "should type 0" do
      @key.type.should == 0
    end

    it "should equals instance of string '123.0.5' instance that is parse result" do
      @key.should == Castoro::BasketKey.parse("123.0.5")
    end

    it "should to_s '123.0.5'" do
      @key.to_s == "123.0.5"
    end

    it "should type_name 'original'" do
      @key.type_name.should == "original"
    end
  end

  context "when :bitmap is specified for type of constructor argument" do
    before do
      @key = Castoro::BasketKey.new(123, :bitmap, 5)
    end

    it "should type 1" do
      @key.type.should == 1
    end

    it "should equals instance of string '123.1.5' instance that is parse result" do
      @key.should == Castoro::BasketKey.parse("123.1.5")
    end

    it "should to_s '123.1.5'" do
      @key.to_s == "123.1.5"
    end

    it "should type_name 'bitmap'" do
      @key.type_name.should == "bitmap"
    end
  end

end

