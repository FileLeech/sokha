require 'eventmachine'

class MaybeWrapper
  def method_missing(*args, &block)
    nil
  end
end

class Object
  def to_bool
    !!self
  end
  
  def as(&block)
    yield self
  end
  
  def maybe
    self ? self : MaybeWrapper.new
  end  

  def maybe_as(options = {}, &block)
    self ? yield(self) : nil
  end
      
  def in?(enumerable)
    enumerable.include?(self)  
  end
  
  def not_in?(enumerable)
    !self.in?(enumerable)  
  end
    
  def state_loop(initial_value, &block)
    value = initial_value
    loop do 
      value = (yield value)
    end
  end
  
  #def cattr_accessor(*args)
  #  self.class_eval do
  #    attr_accessor(*args)
  #  end
  #end
end

class Hash
  def slice(*keys)
    Array(keys).map do |key| 
      [key, self[key]] if self[key]
    end.compact.to_hash 
  end
end

module Enumerable  
  def map_detect(value_for_no_matching = nil)
    self.each do |member|
      if result = yield(member)
        return result
      end
    end    
    value_for_no_matching
  end
  
  def mash(&block)
    self.inject({}) do |hash, item|
      key, value = yield(item)
      hash.merge(key => value) 
    end      
  end
  
  def to_hash
    self.inject({}) do |hash, (key, value)|
      hash.merge(key => value) 
    end
  end

  def lazy_map(&block)
    require 'backports'
    Enumerator.new do |yielder|
      self.each do |value|
        yielder.yield(block.call(value))
      end
    end
  end    
  
  def lazy_select(&block)
    require 'backports'
    Enumerator.new do |yielder|
      self.each do |val|
        yielder.yield(val) if block.call(val)
      end
    end
  end
end

class String
  def splitlines
    self.split(/\n/)  
  end
  
  def inner_strip
    self.strip.gsub(/\s+/, ' ')
  end
  
  def match1(regexp)
    match = self.match(regexp)
    match ? match[1] : nil
  end
  
  def interpolate(namespace)
    namespace.inject(self) do |string, (key, value)|
      string.gsub(/(^|[^%])%#{key}/, "\\1" + value)
    end.gsub(/%%/, '%').inner_strip
  end
end

class Numeric
  def to_human(options = {})
    #options.default!(:decimals => 2, :utils => "B")
    decimals = options.delete(:decimals) || 2
    units_string = options.delete(:units) || "B"
    units = ["", "K", "M", "G", "T"].map { |s| s + units_string }
    e = (Math.log(self)/Math.log(1024)).floor
    s = "%.#{decimals}f" % (self.to_f / 1024**e)
    s.sub(/\.?0*$/, units[e])
  end
end

module EventMachine
  class Popen3StderrHandler < EventMachine::Connection
    include EM::Protocols::LineText2
    
    def initialize(connection)
      @connection = connection
    end
    
    def receive_data(data)
      @connection.receive_stderr(data)
    end
  end  

  def self.popen3(*args, &block)
    new_stderr = $stderr.dup
    rd, wr = IO::pipe
    $stderr.reopen(wr)
    connection = EM.popen(*args, &block)
    $stderr.reopen(new_stderr)
    EM.attach(rd, Popen3StderrHandler, connection)
    connection
  end  
end
