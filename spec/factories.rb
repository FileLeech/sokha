require 'factory_girl'
require 'sokha/setting'
require 'sokha/job'

DataMapper.setup(:default, "sqlite3::memory:")
DataMapper.auto_migrate!

Factory.sequence(:name) do |n|
  "string#{n}"
end

Factory.sequence(:url) do |n|
  "http://url#{n}"
end

Factory.define :setting, :class => Sokha::Setting do |s|
  s.name { Factory.next(:name) }
  s.value "value"  
end

Factory.define :job, :class => Sokha::Job do |s|
  s.url { Factory.next(:url) }
  s.module "mod"
  s.app "app"
end
