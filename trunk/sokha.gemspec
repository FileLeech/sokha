Gem::Specification.new do |s|
  s.name = "sokha"
  s.version = "0.0.1"
  if s.respond_to? :required_rubygems_version=
    s.required_rubygems_version = Gem::Requirement.new(">= 1.2.0")
  end 
  s.rubygems_version = '1.2.0'
  s.authors = ["Arnau Sanchez"]
  s.date = "2010-08-10"
  s.default_executable = "sokhad"
  s.description = "Web frontend for Plowshare (Megaupload/Rapidshare downloader)"
  s.email = "tokland@gmail.com"
  s.executables = ["sokhad"]
  #s.extra_rdoc_files = ["CHANGELOG", "lib/missing_t.rb", "README.markdown", "tasks/missing_t.rake"]
  s.files = ["bin/sokhad", "lib/sokha.rb", "config.yml", "sokha.gemspec", "LICENSE"] +
    %w{_setting.erb jobs.erb layout.erb settings.erb}.map { |p| File.join("views", p) } +  
    %w{archive_stream.rb helpers.rb job_downloader.rb server_main.rb 
       extensions.rb job.rb server.rb setting.rb}.map { |p| File.join("lib/sokha/", p) }  
  s.homepage = "http://github.com/tokland/sokha"
  s.rdoc_options = %w{--line-numbers --inline-source --title Sokha --main README.markdown}
  s.require_paths = ["lib"]
  s.summary =  "Web queue manager for file-sharing (Megaupload, Rapidshare, ...) applications"
  %w{daemons eventmachine em-http-request dm-core dm-timestamps dm-is-state_machine 
     dm-validations dm-migrations sinatra sinatra_more sinatra-reloader rack 
     rack-flash thin rack-contrib dm-sqlite-adapter trollop}.each do |gem_name|
    s.add_dependency(gem_name)
  end
end
