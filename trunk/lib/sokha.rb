module Sokha
  RootDir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  UserDir = File.join(File.expand_path("~"), ".sokha")
  
  def self.create_user_dir
    FileUtils.mkdir_p(UserDir)
  end
end

require 'sokha/extensions'
require 'sokha/job'
require 'sokha/setting'
require 'sokha/server'
