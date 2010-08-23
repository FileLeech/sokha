require 'spec_helper'
require 'sokha/extensions'

describe Object do
  describe "#to_bool" do
    it "should return false for false and nil" do
      false.to_bool.should be_false
      nil.to_bool.should be_false
    end
    
    it "should be true for all non-false/nil objects" do
      true.to_bool.should be_true
      [].to_bool.should be_true
      {}.to_bool.should be_true
      "".to_bool.should be_true
      "hi there".to_bool.should be_true
    end     
  end
  
  describe "#as" do
    it "moves object to block as argument" do
      "hi".as { |s| s.size }.should == 2    
    end
    
    it "moves object to block as multiple arguments for arrays" do
      ["hi", "there"].as { |s1, s2| [s1.size, s2.size] }.should == [2, 5]    
    end
  end
  
  describe "#maybe" do
    it "does nothing for true objects" do
      "hello".maybe.size.should == 5
    end
    
    it "returns a dummy eat-all object for false objects that returns nil" do
      nil.maybe.size.should be_nil
      false.maybe.size.should be_nil
    end
  end
   
  describe "#maybe_as" do
    it "moves object to block for true objects" do
      "hello".maybe_as { |s| s.size }.should == 5
    end
    
    it "returns a dummy eat-all object for false objects that returns nil" do      
      nil.maybe_as { |s| s.size }.should be_nil
      false.maybe_as { |s| s.size }.should be_nil
    end
  end
  
  describe "#in?" do
    it "should check if object is in enumerable" do
      1.in?([1,2,3]).should be_true
      3.in?([1,2,3]).should be_true
      5.in?([1,2,3]).should be_false
    end
    
    it "raises NoMethodError exception when checking on non-enumerables" do
      lambda { 1.in?(10) }.should raise_error(NoMethodError)    
    end
  end 
  
  describe "#not_in?" do
    it "should check if object is not in enumerable" do
      1.not_in?([1,2,3]).should be_false
      3.not_in?([1,2,3]).should be_false
      5.not_in?([1,2,3]).should be_true
    end
    
    it "raises NoMethodError exception when checking on non-enumerables" do
      lambda { 1.not_in?(10) }.should raise_error(NoMethodError)    
    end
  end 
  
  describe "#state_loop" do
    it "call block with function loop's argument on the first call" do
      state_loop("hello") do |s| 
        s.should == "hello"
        break
      end
    end

    it "call block with the result of the block on the next call" do
      nloop = 1
      state_loop(1) do |n|
        break if nloop > 3
        n.should == nloop
        nloop += 1 
        n + 1
      end
    end

    it "should return value of break" do
      state_loop(1) do |n|
        break n if n > 3       
        n + 1
      end.should == 4
    end    
  end
end

describe Hash do
  describe "#slice" do
    it "should return a new hash only with key in arguments" do
      hash = {1 => "a", 2 => "b", 3 => "c"}
      hash.slice.should == {}
      hash.slice(1).should == {1 => "a"}
      hash.slice(1, 2).should == {1 => "a", 2 => "b"}
      hash.slice(1, 2, "nonkey").should == {1 => "a", 2 => "b"}
    end
  end
end

describe Enumerable do
  describe "#map_detect" do
    it "should return the first true result in the mapping" do
      [1, 2, 3, 4, 5].map_detect do |n|
        2*n if n > 3
      end.should == 8
    end
  end

  describe "#to_hash" do
    it "should return a hash from enumerable" do
      [[1, 2], [3, 4]].to_hash.should == {1 => 2, 3 => 4}
      [[1, 2], nil].to_hash.should == {1 => 2, nil => nil}
    end
  end
  
  describe "#mash" do
    it "map + to_hash" do
      [[1, 2], [3, 4]].mash do |k, v|
        [2*k, 3*v]
      end.should == {2 =>  6, 6 => 12}
    end
  end
  
  describe "#lazy_map" do
    inf = 1.0/0
    (1..inf).lazy_map { |x| 2 * x }.first(3).should == [2, 4, 6]
  end
  
  describe "#lazy_select" do
    inf = 1.0/0
    (1..inf).lazy_select { |x| x > 10 }.first(3).should == [11, 12, 13]
  end
end

describe String do
  describe "#splitlines" do
    it "should split lines of string" do
      "hi\nthere\npal".splitlines.should == %w{hi there pal}
      "hi\nthere space\npal".splitlines.should == ["hi", "there space", "pal"]
    end
  end
  
  describe "#inner_strip" do
    it "should do a standard strip and remove more than one space in the string" do
      " x     y    z  ".inner_strip.should == "x y z"
      "a\n  b  \t   c".inner_strip.should == "a b c"
    end
  end
  
  describe "#match1" do
    it "should return first Regexp match (nil otherwise)" do
      "a b10 c".match1(/(z)/).should be_nil
      "a b10 c".match1(/(b\d+)/).should == "b10"
    end 
  end
  
  describe "interpolate" do
    it "should interpolate using % format" do
      "%name is %age years old".interpolate(:name => 'John', :age => '20').
        should == "John is 20 years old"
    end
    it "should allows escaped %" do
      "%result %%hello".interpolate(:result => '60').should == "60 %hello"
    end
  end
end

describe Numeric do
  describe "#to_human" do
    it "should show nice units" do
      12.to_human.should == "12B"
      1234.to_human.should == "1.21KB"
      1234567.to_human.should == "1.18MB"
      1234567890.to_human.should == "1.15GB"
    end

    it "should have decimals as option" do
      1234.to_human(:decimals => 3).should == "1.205KB"
    end
    
    it "should have units as option" do
      1234.to_human(:units => "Q").should == "1.21KQ"
    end
  end
end

describe EventMachine do
  describe "popen3" do
    before do
      class Handler < EventMachine::Connection
        attr_accessor :data, :stderr
        
        def initialize
          self.data = ""
          self.stderr = ""
        end
        
        def receive_data(data)
          self.data += data
        end
        
        def receive_stderr(data)
          self.stderr += data
        end
        
        def unbind
          EM.stop
        end
      end
      
      EM.run do 
        @connection = EM.popen3("bash -c 'echo hello; echo there >&2'", Handler)        
      end
    end
        
    it "should acts as popen but call also receive_stderr on data for STDERR" do
      @connection.data.should == "hello\n"
      @connection.stderr.should == "there\n"      
    end
  end
end
