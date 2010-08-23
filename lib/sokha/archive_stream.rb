require 'shellwords'

class ArchiveStream
  def initialize(paths, buffersize = 8192)
    @paths = paths
    @buffersize = buffersize
  end
  
  def each(&block)
    command = ["tar", "cz"] + @paths.map do |path|
      ["-C", File.dirname(path), File.basename(path)]
    end.flatten
    IO::popen(Shellwords.shelljoin(command)) do |stdout|
      while data = stdout.read(@buffersize)
        yield data
      end
    end 
  end
  
  def self.send_stream(name, filepaths)  
    headers = {
      "Content-disposition" => "attachment; filename=\"#{name}.tgz\"",
      "Content-type" => "application/x-gtar",
    }    
    throw :response, [200, headers, ArchiveStream.new(filepaths)]
  end
end
