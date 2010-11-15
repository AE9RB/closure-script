# Copyright 2010 The Googlyscript Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


class Googly
  
  class Response
    
    def self.not_found
      body = "404 Not Found\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
    
    def initialize(env, filename, content_type = nil)
      @env = env
      @filename = filename
      @status = 500
      @headers = {}
      @body = ['500 Internal Server Error (Googly::Response)']
      @override = nil
      
      begin
        raise Errno::EPERM unless File.file?(filename) and File.readable?(filename)
      rescue SystemCallError
        @status = 404
        return
      end
      
      # Caching strategy
      if_mod_since = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE']) rescue nil
      if env['QUERY_STRING'] =~ /^[0-9]{9,10}$/
        # Files timestamped with unix time in QUERY_STRING are supercharged
        # The automatic deps.js contains filenames in this format.
        @status = 304 if if_mod_since and File.mtime(filename) == Time.at(env['QUERY_STRING'].to_i)
        @headers["Last-Modified"] = Time.now.httpdate
        @headers["Cache-Control"] = 'max-age=86400, public' # one day
      else
        # Regular files must always revalidate with timestamp
        last_modified = File.mtime(filename)
        @status = 304 if last_modified == if_mod_since
        @headers["Last-Modified"] = last_modified.httpdate
        @headers["Cache-Control"] = 'max-age=0, private, must-revalidate'
      end
      return if @status == 304
      
      # Sending the file or reading an unknown length stream to send
      @status = 200
      @body = self
      unless size = File.size?(filename)
        @body = [File.read(filename)]
        size = body.first.respond_to?(:bytesize) ? body.first.bytesize : body.first.size
      end
      @headers["Content-Length"] = size.to_s
      @headers["Content-Type"] = content_type || Rack::Mime.mime_type(File.extname(filename), 'text/plain')
    end
    
    # These support using self as a high-performance body
    def each
      File.open(@filename, "rb") { |file|
        while part = file.read(8192)
          yield part
        end
      }
    end
    attr_reader :filename
    alias :to_path :filename

    def found?
      @status == 200 or @status == 304
    end
  
    def finish
      return self.class.not_found if @status == 404
      [@status, @headers, @body]
    end
  
  end

end



