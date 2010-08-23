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
    
    it "that filepath is nil or length > 1" do
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
end
