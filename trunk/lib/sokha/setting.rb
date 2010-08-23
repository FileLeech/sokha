require 'sokha'

class Sokha::Setting
  include DataMapper::Resource
  storage_names[:default] = "settings"

  property :id, Serial  
  property :name, String, :required => true, :length => 1024, :unique => true
  property :value, String, :length => 1024
  property :title, String, :length => 1024  
  property :default, String, :length => 1024
  property :type, String
  property :position, Integer
    
  class << self  
    attr_accessor :config
  end
  
  def self.by_position
    self.all(:order => :position.asc)
  end
  
  def self.set_config(config_file)    
    self.config = YAML::load_file(config_file)
  end
  
  def self.reset
    Sokha::Setting.destroy
    self.create_from_yaml(["global-options"], self.config["global-options"])    
    self.config["apps"].each do |app_key, app_opts|
      app_opts["modules"].each do |mod_key, mod_opts|
        if options = mod_opts["options"]
          self.create_from_yaml(["apps", app_key, mod_key, "options"], options)
        end
      end
    end    
  end

  def self.get_by_name(*path)
    self.first(:name => Array(path).join("."))
  end
  
  def self.value(*path)
    self.get_by_name(*path).maybe.value
  end

  def self.in_section(*path)
    self.all(:name.like => Array(path).join(".") + "%")
  end

  def self.group_in_section(*path)
    self.in_section(path).group_by do |setting|
      setting.name.split(".")[path.size]
    end
  end
  
  def self.info_for_url(url)
    self.config["apps"].map_detect do |app, opts|
      command = opts["commands"]["get-module"]["command"].interpolate(:url => url, :options => "")
      if mod = self.run(command).splitlines.first.maybe.strip
        [mod, app]
      end
    end
  end
  
  def self.command_for_job(job)
    options_namespace = self.in_section(["apps", job.app, job.module, "options"]).mash do |setting|
      [setting.name.split(".").last, setting.value.maybe.strip || ""]
    end
    options = options_namespace.map do |name, value|
      unless value.empty?
        self.config["apps"][job.app]["commands"][job.module].maybe["options"].
          maybe[name]["command-option"].maybe.interpolate(options_namespace)
      end
    end.compact
    command = self.config["apps"][job.app]["commands"]["download-info"]["command"]
    options << self.config["apps"][job.app] ["modules"][job.module].maybe["url_options"].
      maybe["password"].maybe.interpolate(:password => job.url_password) if job.url_password
    command.interpolate(:url => job.url, :options => options.join(" "))
  end  
  
  def self.get_http_auth
    user = Sokha::Setting.value(["global-options", "auth-user"]) || "admin"
    password = Sokha::Setting.value(["global-options", "auth-password"]) || "admin"
    [user, password]
  end

private

  def self.run(command)
    %x{#{command}}
  end
  
  def self.create_from_yaml(path, yaml)
    yaml.map do |key, opts|
      name = (path + [key]).join(".")
      setting = Sokha::Setting.first(:name => name) || Sokha::Setting.new(:name => name)
      setting.attributes = {
        :value => setting.new? ? opts["default"] : setting.value,
        :position => opts["position"], 
        :title => opts["title"],
        :type => opts["type"],
      }
      setting.save
      setting
    end
  end  
end
