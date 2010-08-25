require 'dm-core'
require 'dm-timestamps'
require 'dm-is-state_machine'
require 'dm-validations'

class Sokha::Job  
  include DataMapper::Resource
  storage_names[:default] = "jobs"

  property :id, Serial  
  property :url, String, :required => true, :length => 1024, :unique => true
  property :url_password, String, :length => 256
  property :module, String, :required => true
  property :app, String, :required => true
  property :error_key, String
  property :error_description, Text
  property :error_retry, Boolean
  property :filename, String, :length => 1024
  property :filepath, String, :length => 1024
  property :file_downloaded, Integer
  property :file_size, Integer
  property :created_at, DateTime
  property :updated_at, DateTime

  validates_length_of :filepath, :min => 1, :if => proc { |j| j.filepath }
    
  is :state_machine, :initial => :queued, :column => :state do
    state :queued
    state :active
    state :stopped
    state :done
    state :error

    event :activate do
      transition :from => :queued, :to => :active
    end
    event :stop do
      transition :from => :active, :to => :stopped
    end
    event :dequeue do
      transition :from => :queued, :to => :stopped
    end 
      
    event :requeue do
      transition :from => :active, :to => :queued
      transition :from => :stopped, :to => :queued
      transition :from => :error, :to => :queued
    end
    event :finish do
      transition :from => :active, :to => :done # :guard => { |job| job.filepath }
    end
    event :finish_with_error do
      transition :from => :active, :to => :error # :guard => { |job| job.error }
    end
  end
   
  def self.all_by_state(state_or_states)
    Job.all(:state => Array(state_or_states).map(&:to_s))
  end
  
  def event(new_state, new_attributes = {})
    self.attributes = new_attributes
    if self.send(new_state.to_s + "!") && self.save
      self
    else
      false
    end      
  end
  
  def self.to_activate(maximum_per_module = 1)
    Job.all_by_state(:queued).group_by(&:module).map do |klass, jobs|
      n_active = self.all(:state => 'active', :module => klass).count
      jobs.first(maximum_per_module - n_active)
    end.flatten
  end          
   
  def percentage_done
    if self.state == "done"
      100.0
    elsif self.file_downloaded && self.file_size && self.file_size > 0 
      100.0 * self.file_downloaded / self.file_size
    else
      0.0
    end
  end                
  
  def self.add_urls(urls)
    urls.map do |url0|
      url, password = url0.split("|")
      mod, app = Sokha::Setting.info_for_url(url)
      job = Job.create(:url => url, :module => mod, :app => app, :url_password => password)
      job if job.valid?
    end.compact
  end
  
  def update_error_fields(status)
    app_opts = Sokha::Setting.config["apps"][self.app]
    info = app_opts["commands"]["download-info"]["error-codes"].maybe[status]
    key, description, retryable = if info
      info.values_at("key", "description", "retry")
    else
      ["unknown", "Unknown error", false]
    end    
    self.event(:finish_with_error, :error_key => key, 
      :error_description => description, :error_retry => retryable)  
  end
  
  def remove_file
    if self.filepath && File.exists?(self.filepath)    
      File.delete(self.filepath) 
      self.filepath
    end
  end    
end
