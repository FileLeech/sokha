require 'spec_helper'
require 'factories'
require 'sokha/setting'

yamlfile = File.join(File.dirname(__FILE__), "fixtures/config.yml")
Sokha::Setting.set_config(yamlfile)
 
describe Sokha::Setting do
  describe "should validate" do 
    it "unique name" do
      setting1 = Factory(:setting)
      setting2 = Factory.build(:setting, :name => setting1.name)
      setting2.should_not be_valid    
    end
  end  
  
  describe "#by_position" do
    settings = 10.downto(1).map { |pos| Factory(:setting, :position => pos) }
    Sokha::Setting.all.by_position.should == settings.reverse
  end  
  
  describe "reset" do
    before do
      Sokha::Setting.config = {
        "global-options" => {
          "opt1" => { 
            "title" => "Opt1 title",
            "type" => "integer",
            "default" => 10,
            "position" => 1,
          }
        },
        "apps" => {
          "myapp" => {
            "modules" => {
              "mymod" => {
                "options" => {
                  "opt2" => {
                    "title" => "Opt2 title",
                    "type" => "string",
                    "default" => "default_value",
                    "position" => 1,
                  }
                }
              }
            }
          }
        }
      }    
      @setting = Factory(:setting)
      Sokha::Setting.reset
    end
    
    it "should destroy old settings" do    
      Sokha::Setting.get(@setting.id).should be_nil
    end
    
    it "should create setttings from config" do
      Sokha::Setting.count.should == 2
      Sokha::Setting.first(:name => "global-options.opt1").as do |s1|
        s1.should_not be_nil
        s1.value.should == "10"
        s1.type.should == "integer"
        s1.position.should == 1
      end
      Sokha::Setting.first(:name => "apps.myapp.mymod.options.opt2").as do |s2|
        s2.should_not be_nil
        s2.value.should == "default_value"
        s2.type.should == "string"
        s2.position.should == 1
      end      
    end    
  end
  
  describe "get_by_name" do
    before do
      Sokha::Setting.destroy
      @s1 = Factory(:setting, :name => 'sec1.sec2.name1')
      @s2 = Factory(:setting, :name => 'sec2.sec5.name4')
    end
    
    it "should get existing settings" do
      Sokha::Setting.get_by_name(["sec1", "sec2", "name1"]).should == @s1
      Sokha::Setting.get_by_name("sec1", "sec2", "name1").should == @s1
      Sokha::Setting.get_by_name("sec2", "sec5", "name4").should == @s2
    end
    
    it "should return nil for non existing settings" do
      Sokha::Setting.get_by_name("sec2", "sec5", "notfound").should be_nil
    end
  end
  
  describe "value" do
    before do
      Sokha::Setting.destroy
      @s1 = Factory(:setting, :name => 'sec1.sec2.name1', :value => "val1")
    end
    
    it "should get value for existing settings" do
      Sokha::Setting.value("sec1", "sec2", "name1").should == @s1.value
    end
    
    it "should return nil for non existing settings" do
      Sokha::Setting.value("sec2", "sec5", "notfound").should be_nil
    end
  end  
  
  describe "in_section" do
    before do
      Sokha::Setting.destroy
      @s1 = Factory(:setting, :name => 'sec1.sec2.name1')
      @s2 = Factory(:setting, :name => 'sec1.sec2.name2')
    end

    it "should get settings for sections" do
      Sokha::Setting.in_section("sec1", "sec2").should have_same_set([@s1, @s2])
      Sokha::Setting.in_section("sec1", "sec2-wrong").should be_empty
    end
    
    it "should get rescursive settings for sections" do
      Sokha::Setting.in_section("sec1").should have_same_set([@s1, @s2])
    end    
  end  
  
  describe "group_in_section" do
    before do
      Sokha::Setting.destroy
      @s1 = Factory(:setting, :name => 'sec1.sec1.name1')
      @s2 = Factory(:setting, :name => 'sec1.sec2.name2')
      @s3 = Factory(:setting, :name => 'sec2.name3')
    end

    it "should group settings in a section" do
      groups = Sokha::Setting.group_in_section(["sec1"])
      groups.keys.should == ["sec1", "sec2"]
      groups["sec1"].should == [@s1]
      groups["sec2"].should == [@s2]
    end
  end
  
  describe "info_for_url" do
    Sokha::Setting.should_receive(:run).
      with('plowdown -v2 --get-module "http://www.megaupload.com/?d=12345"').
      and_return("module")
    Sokha::Setting.info_for_url("http://www.megaupload.com/?d=12345").
      should == ["module", "plowshare"]  
  end  
  
  describe "command_for_job" do
    job = Factory(:job, :app => 'plowshare', :url => "someurl")
    Sokha::Setting.command_for_job(job).
      should == 'plowdown -v2 --download-info-only="%url|%cookies|%filename" "someurl"'
  end
  
  describe "http_auth" do
    it "should get user/password in a pair" do
      Sokha::Setting.create(:name => "global-options.auth-user", :value => 'myuser')
      Sokha::Setting.create(:name => "global-options.auth-password", :value => 'mypassword')
      Sokha::Setting.get_http_auth.should == ["myuser", "mypassword"]
    end
    
    it "should get admin/admin by default" do
      Sokha::Setting.destroy
      Sokha::Setting.get_http_auth.should == ["admin", "admin"]
    end          
  end  
end
