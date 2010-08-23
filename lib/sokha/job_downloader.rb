require 'eventmachine'
require 'em-http-request'
require 'cgi'
require 'fileutils'
require 'sokha'

class Sokha::JobDownloader < EventMachine::Connection
  include EM::Protocols::LineText2
  
  attr_accessor :job, :http, :stderr

  def self.start_worker(job,  activate_workers_block)
    command = Sokha::Setting.command_for_job(job)
    STDERR.puts("run command: #{command}")
    EM.popen3(command, self, job, activate_workers_block)
  end  
  
  def initialize(job, activate_workers_block)
    self.job = job
    self.job.event(:activate)      
    self.stderr = []
    self.http = nil
    @activate_workers_block = activate_workers_block
    @buffer = ""
    if timeout = Sokha::Setting.value(["global-options", "timeout"])
      EventMachine::add_timer(timeout) do
        unless self.http
          self.stop_worker
          job.reload
          if job.state == "active"
            job.event(:finish_with_error, :error_key => 'timeout',  
              :error_description => "Timeout reached: #{timeout}")
          end
          @activate_workers_block.call
        end
      end
    end    
  end
  
  def get_cookies_headers(url, cookies)
    host = URI::parse(URI::encode(url)).host 
    cookies.split(/\n/).map do |line|
      next if line.match(/^#/)
      fields = line.split
      next unless fields.size == 7
      domain, path, name, value = fields.values_at(0, 2, 5, 6)
      next unless host.end_with?(domain.sub(/^\./, ''))        
      cookie = CGI::Cookie.new("name" => name, "value" => value, "path" => path)
      ["Cookie", cookie.to_s] 
    end.compact
  end
  
  def get_header(key, hash)
    hash.map_detect do |k, v| 
      v if k.downcase == key.to_s
    end
  end
  
  def receive_stderr(data)
    STDERR.write(data) 
    self.stderr << data 
  end 
    
  def receive_data(alldata)
    STDERR.puts("receive_data: #{alldata}")
    job.reload
    return unless job.state == "active"
    #@buffer += alldata
    #index = @buffer.rindex("\n")
    #return unless index
    fileurl, cookiesfile, filename = alldata.strip.split("|")
    download_file(fileurl, cookiesfile, filename)
  end

  def noclobber_path(start_path)
    extension = File.extname(start_path)
    header = start_path[0, start_path.size - extension.size]
    state_loop([start_path, 1]) do |path, index|
      break path if !File.exists?(path)
      ["#{header}.#{index}#{extension}", index + 1]
    end
  end

  def download_file(fileurl, cookiesfile, filename, options = {})          
    cookies = []
    @fd = nil
    last = 0
    size = 0
    now, total = 0, nil
    #we need to control when a site accepts ranges
    #if self.job.filepath && File.exists?(self.job.filepath)
    #  size = File.size(self.job.filepath)        
    #  cookies << ["Range", "bytes=#{size}-"]
    #  now = size
    #  fd = open(filename, "a")
    #end
    
    cookies_data = cookiesfile.empty? ? "" : open(cookiesfile).read
    head = cookies + get_cookies_headers(fileurl, cookies_data)
    STDERR.puts("request: #{fileurl} - #{head.inspect}")
    self.http = EventMachine::HttpRequest.new(fileurl).get(:redirect => true, :head => head)
    self.job.reload
    
    self.http.stream do |chunk|
      unless @fd
        remote_filename = get_header(:content_disposition, 
          self.http.response_header).maybe.match1(/filename=(.*)$/)            
        filename = remote_filename || 
          URI::decode(File.basename(URI::parse(URI::encode(fileurl)).path))
        temp_dir = File.expand_path(Sokha::Setting.get_by_name(["global-options", "temporal-directory"]).value)
        FileUtils.mkdir_p(temp_dir)
        temp_path = noclobber_path(File.join(temp_dir, filename))
        @fd = open(temp_path, "w")
        self.job.update(:filename => filename, :filepath => temp_path)
      end 
      total ||= get_header(:content_length, self.http.response_header).to_i + size 
      now += chunk.size
      if now - last > 100000
        STDERR.puts("download: #{now}/#{total}")
        self.job.update!(:file_downloaded => now, :file_size => total)
        last = now
      end
      loop do 
        begin
          @fd.write(chunk)
          break
        rescue Errno::EBADF => exc
          STDERR.puts(exc.to_s)
          # why?
          @fd = open(@fd.path, "a")
        end
      end
    end
    
    self.http.callback do
      @fd.close
      self.job.reload
      http_status = self.http.response_header.status
      STDERR.puts("HTTP code: #{http_status}") 
      if http_status >= 200 && http_status < 300
        incoming_dir = File.expand_path(Sokha::Setting.get_by_name(["global-options", "incoming-directory"]).value)
        FileUtils.mkdir_p(incoming_dir)
        incoming_path = noclobber_path(File.join(incoming_dir, self.job.filename))
        FileUtils.mv(self.job.filepath, incoming_path)          
        self.job.event(:finish, :filepath => incoming_path)
      else
        self.job.event(:finish_with_error, :error_key => "download", 
          :error_description => "Download process got HTTP code '#{http_status}'")
      end          
      @activate_workers_block.call
    end
  end
  
  def unbind
    exit_status = get_status.exitstatus & 255
    STDERR.puts("command exit status: #{exit_status}")
    self.job.reload
    if job.state == "active" && exit_status && exit_status != 0
      self.job.update_error_fields(exit_status)
      @activate_workers_block.call
    end
  end
  
  def stop_worker
    # better use ps --ppid=xxx recursively 
    pids = %x{pstree -p #{self.get_pid}}.scan(/\((\d+)\)/).flatten
    STDERR.puts("TERM: #{pids.inspect}")
    pids.each do |pid|
      begin
        Process.kill("TERM", pid.to_i)
      rescue Errno::ESRCH, Errno::EPERM => exc
        STDERR.puts("TERM exception: #{exc.to_s}") 
      end
    end
    self.http.close_connection if self.http
    job.reload
  end
  
  def stop
    stop_worker
    job.event(:stop)
  end  
end
