require 'spec_helper'
require 'sokha/archive_stream'

describe ArchiveStream do
  before do
    @filepaths = ["/etc/services", "/etc/hosts"]
  end
  
  describe "send_stream" do
    it "should throw a :response with [code, headers, iterable]" do
      lambda do
        ArchiveStream.send_stream("name", @filepaths)
      end.should throw_symbol(:response)
    end
  end
  
  describe "#each" do
    it "should get archive data" do
      stream = ArchiveStream.new(@filepaths)
      stream.enum_for(:each).map.join.should_not be_empty
    end
  end
end
