require 'spec_helper'
require 'factories'
require 'sokha/job'

yamlfile = File.join(File.dirname(__FILE__), "fixtures/config.yml")
Sokha::Setting.set_config(yamlfile)
 
describe Sokha::Job do
  it { Factory.build(:job).should be_valid }
  
  describe "should validate" do 
    it "unique url" do
      job1 = Factory(:job)
      job2 = Factory.build(:job, :url => job1.url)
      job2.should_not be_valid    
    end
    
    it "that filepath is null or with length > 1" do
      Factory.build(:job, :filepath => nil).should be_valid
      Factory.build(:job, :filepath => "").should_not be_valid
      Factory.build(:job, :filepath => "a").should be_valid
    end
  end
  
  describe "all_by_state" do
    it "should get jobs with a state" do
      Sokha::Job.destroy
      job1 = Factory(:job, :state => "queued")
      job2 = Factory(:job, :state => "active")
      job3 = Factory(:job, :state => "active")
      job4 = Factory(:job, :state => "error")
      Sokha::Job.all_by_state(:queued).should have_same_set([job1])
      Sokha::Job.all_by_state(:active).should have_same_set([job2, job3])
      Sokha::Job.all_by_state([:queued, :error]).should have_same_set([job1, job4])
    end
  end 
  
  describe "#event" do
    before do
      @job1 = Factory(:job, :state => "queued")
    end
    
    it "should run a transition event and update other attributes" do
      @job1.event(:activate, :filepath => "path").should == @job1
      @job1.reload
      @job1.state.should == "active"
      @job1.filepath.should == "path"    
      @job1.should_not be_dirty
    end
      
    it "should return false when object does not update (and keep old state)" do
      @job1.event(:activate, :filepath => "").should be_false
      @job1.reload
      @job1.state.should == "queued"
    end  
  end 
  
  describe "to_active" do
    before do
      Job.destroy
      @job1 = Factory(:job, :state => "queued", :module => 'mod1')
      @job2 = Factory(:job, :state => "stopped", :module => 'mod1')
      @job3 = Factory(:job, :state => "done", :filepath => 'path', :module => 'mod2')
      @job4 = Factory(:job, :state => "queued", :module => 'mod2')
    end
    
    it "should get 1 queued job per module" do
      Job.to_activate.should have_same_set([@job1, @job4])    
    end 
  end
  
  describe "percentage done" do
    it "should return 0.0 for jobs without info" do
      Factory(:job, :state => 'queued').percentage_done.should be_close(0.0, 0.001)
      Factory(:job, :state => 'queued').percentage_done.should be_close(0.0, 0.001)
    end
    
    it "should return the % for non-done" do
      Factory(:job, :state => 'queued', :file_downloaded => 1, 
        :file_size => 3).percentage_done.should be_close(100/3.0, 0.001)
    end
    
    it "should return 100.0 for done jobs" do
      Factory(:job, :state => 'done', :filepath => 'a').percentage_done.should be_close(100.0, 0.001)      
    end
  end
  
  describe "add_urls" do
    before(:all) do
      Job.destroy
      @urls = [
        "http://www.megaupload.com/?d=1234", 
        "http://unknown.com/1234",
        "http://rapidshare.com/files/12345",
      ] 
      @jobs = Job.add_urls(@urls)
    end
    
    it "should create saved jobs" do
      @jobs.any?(&:new?).should be_false      
    end
    
    it "should return only valid jobs" do
      @jobs.all?(&:valid?).should be_true
      @jobs.size.should == 2
      @jobs[0].url.should == @urls[0]
      @jobs[1].url.should == @urls[2]      
    end
  end
  
  describe "#update_error_fields" do
    before do 
      @job = Factory(:job, :state => 'active', :app => 'plowshare')
    end
    
    describe "with known status" do
      it "should transition to error updating error_key/description/retry" do
        @job.update_error_fields(1)
        @job.state.should == "error"
        @job.should_not be_dirty
        @job.error_key.should == "fatal"
        @job.error_description.should == "Fatal error"
        @job.error_retry.should be_false 
      end
    end   

    describe "with unknown status" do
      it "should transition to default error and no retryable" do
        @job.update_error_fields(100)
        @job.should_not be_dirty
        @job.state.should == "error"
        @job.error_key.should == "unknown"
        @job.error_description.should == "Unknown error"
        @job.error_retry.should be_false 
      end
    end
  end
  
  describe "#remove_file" do
    describe "with no file" do
      before { @job = Factory(:job, :filepath => nil) }
      
      it "should do nothing" { @job.remove_file }
    end
    
    describe "with file" do
      before do
        @tempfile = Tempfile.new("test") 
        @job = Factory(:job, :filepath => @tempfile.path)
      end
      
      it "should remove file" do
        File.exists?(@tempfile.path).should be_true
        @job.remove_file
        File.exists?(@tempfile.path).should be_false           
      end
    end
  end
end
