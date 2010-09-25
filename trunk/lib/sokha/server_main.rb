require 'dm-migrations'
require 'trollop'
require 'fileutils'

require 'sokha'

options = Trollop::options do
  banner "Sokha server"
  opt :database, "File database", :type => :string 
  opt :reset_database, "Reset database"
end

dbfile = options[:database_file] || File.join(Sokha::UserDir, "sokha.sqlite")
DataMapper.setup(:default, "sqlite3:" + dbfile)

Dir.chdir(Sokha::RootDir)
Sokha::Setting.set_config("config.yml")

if options[:reset_database] || !File.exists?(dbfile)
  DataMapper.auto_migrate!
  Sokha::Setting.reset
end

Sokha::Job.all_by_state(:active).each { |job| job.event(:requeue) }
Sokha::QueueServer.http_auth_basic = Sokha::Setting.get_http_auth

loop do 
  begin    
    EM.run do
      Sokha::QueueServer.activate_workers
      Sokha::QueueServer.run!(:host => 'localhost', :port => 4567)
    end
    break
  rescue SystemExit, Interrupt
    raise
  rescue Exception => exc
    STDERR.puts(exc.to_s+"\n"+exc.backtrace.join("\n"))
    sleep(1)
  end
end
