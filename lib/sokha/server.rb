require 'sinatra/base'
require "sinatra/reloader" #if development?
require 'sinatra_more/markup_plugin'
require 'erb'
require 'rack-flash' 
require 'rack/contrib'
require 'dm-migrations'
require 'trollop'
require 'fileutils'

require 'sokha'
require 'sokha/job_downloader'
require 'sokha/archive_stream'
require 'sokha/helpers'

Job = Sokha::Job

class Sokha::QueueServer < Sinatra::Base
  register SinatraMore::MarkupPlugin
  helpers Sokha::Helpers
  enable :sessions
  set :method_override, true
  set :lock, true
  set :server, ["thin"]
  cattr_accessor :workers, :setting, :http_auth_basic
  set :public, File.join(File.dirname(__FILE__), '../../static')
  use Rack::Flash, :sweep => true
  use Rack::Evil
  set :daemonize, true
  configure :development do |c|
    register Sinatra::Reloader
    also_reload "*.rb"
  end
  
  use Rack::Auth::Basic do |username, password|
    self.http_auth_basic ? ([username, password] == self.http_auth_basic) : true
  end
  
  configure do |queue_server|
    queue_server.workers = {}
  end
  
  get '/settings' do
    erb :settings, :locals => {
      :global_options => Sokha::Setting.in_section(["global-options"]), 
    }
  end

  put '/settings' do
    params.each do |name, value|
      Sokha::Setting.first(:name => name).maybe.update(:value => value)
    end  
    #self.http_auth_basic = Sokha::Setting.get_http_auth
    flash[:notice] = "Settings saved"
    redirect '/settings'
  end
  
  get '/' do
    erb :jobs, :locals => {:jobs => Job.all, :workers => self.workers}
  end

  get '/enqueue' do
    redirect '/'
  end

  post '/enqueue' do
    urls = params[:urls].splitlines.map(&:strip).reject(&:empty?)    
    queued_jobs = Job.add_urls(urls)
    self.class.activate_workers
    flash[:notice] = "#{queued_jobs.size} jobs added to the queue"
    redirect '/'
  end

  post '/clear' do
    hash_jobs = {
      :done => Job.all_by_state(:done),
      :error => Job.all_by_state(:error),
      :non_retryable => Job.all(:state => 'error', :error_retry => false),
    }
    cleared_jobs = (hash_jobs[params[:what].maybe.to_sym] || []).map do |job|
      job.destroy
      job
    end
    flash[:notice] = "#{cleared_jobs.size} jobs cleared"
    redirect '/'
  end

  post '/' do
    keys = %w{delete stop requeue retry download dequeue clear}
    action, job_id = keys.map_detect do |key| 
      params.keys.map_detect do |params_key|
        action, id = params_key.split("-")
        [action, id] if action == key
      end
    end    
    jobs = Job.all(:id => (job_id || Array(params[:job_ids]).flatten))
    
    case action.maybe.to_sym
    when :clear
      jobs_cleared = jobs.all_by_state([:done, :error]).map do |job|
        job.destroy
        job
      end      
      flash[:notice] = "#{jobs_cleared.size} jobs cleared"
      self.class.activate_workers    
    when :delete
      jobs.all_by_state(:active).each do |job|
        worker = self.workers[job]
        worker.maybe.stop
      end      
      jobs.each do |job|
        job.remove_file
        job.destroy
      end
      flash[:notice] = "#{jobs.size} jobs deleted"
      self.class.activate_workers
    when :stop
      stopped_jobs = jobs.all_by_state(:active).map do |job|
        worker = self.workers[job]
        worker.maybe.stop && job
      end
      flash[:notice] = "#{stopped_jobs.size} jobs stopped"
      self.class.activate_workers
    when :dequeue
      dequeued_jobs = jobs.all_by_state(:queued).select do |job|
        job.event(:dequeue)
      end
      flash[:notice] = "#{dequeued_jobs.size} jobs dequeued"
      self.class.activate_workers
    when :requeue
      resumed_jobs = jobs.all_by_state(:stopped).select do |job|
        job.event(:requeue)
      end
      flash[:notice] = "#{resumed_jobs.size} jobs resumed"
      self.class.activate_workers
    when :retry
      retried_jobs = jobs.all_by_state(:error).select do |job|
        if job.event(:requeue)
          self.workers[job].maybe_as { |worker| worker.stderr.clear }
          true
        end
      end
      flash[:notice] = "#{retried_jobs.size} jobs retried"
      self.class.activate_workers
    when :download
      filepaths = jobs.all_by_state(:done).map(&:filepath)
      if filepaths.empty?
        flash[:error] = "Nothing to download"
      #elsif filepaths.size == 1
      #  puts filepaths.first
      #  send_file(filepaths.first)
      #  return
      else
        name = "job-" + jobs.map(&:id).join("_")
        ArchiveStream.send_stream(name, filepaths)
      end
    else
      flash[:error] = "Unknown operation"
    end
    redirect "/"
  end

  put '/:id' do |id|
    job = Job.get(id) || raise(Sinatra::NotFound)
    job.update(params.slice(:state))
    redirect '/'
  end
  
  delete '/:id' do |id|
    job = Job.get(id) || raise(Sinatra::NotFound)
    job.remove_file
    job.destroy
    redirect '/'
  end
  
  get '/file/:id/:filename' do |id, filename|
    job = Job.get(id) || raise(Sinatra::NotFound)
    send_file(job.filepath)
  end
  
  def self.activate_workers
    activated_workers = Job.to_activate.mash do |job|
      worker = Sokha::JobDownloader.start_worker(job, self.method(:activate_workers))
      [job, worker]
    end
    self.workers.update(activated_workers)
    if Sokha::Setting.value(["global-options", "retry-policy"]) == "true"
      Job.all(:state => "error", :error_retry => true).each do |job|
        job.event(:requeue)
      end
    end
  end    
end
