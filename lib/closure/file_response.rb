# Copyright 2011 The Closure Script Authors
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


class Closure
  
  # Can be used as a Rack::Response.  Provides advanced cache control.
  
  class FileResponse
    
    def initialize(env, filename, content_type = nil)
      @env = env
      @filename = filename
      @status = 200
      @headers = {}
      @body = []
      
      begin
        raise Errno::EPERM unless File.file?(filename) and File.readable?(filename)
      rescue SystemCallError
        @body = ["404 Not Found\n"]
        @headers["Content-Length"] = @body.first.size.to_s
        @headers["Content-Type"] = "text/plain"
        @headers["X-Cascade"] = "pass"
        @status = 404
        return
      end
      
      # Caching strategy
      mod_since = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE']) rescue nil
      last_modified = File.mtime(filename)
      @status = 304 and return if last_modified == mod_since
      @headers["Last-Modified"] = last_modified.httpdate
      if env['QUERY_STRING'] =~ /^[0-9]{9,10}$/ and last_modified == Time.at(env['QUERY_STRING'].to_i)
        @headers["Cache-Control"] = 'max-age=86400, public' # one day
      else
        @headers["Cache-Control"] = 'max-age=0, private, must-revalidate'
      end
      
      # Sending the file or reading an unknown length stream to send
      @body = self
      unless size = File.size?(filename)
        @body = [File.read(filename)]
        size = @body.first.respond_to?(:bytesize) ? @body.first.bytesize : @body.first.size
      end
      @headers["Content-Length"] = size.to_s
      @headers["Content-Type"] = content_type || Rack::Mime.mime_type(File.extname(filename), 'text/plain')
    end
    
    # Support using self as a response body.
    # @yield [String] 8k blocks
    def each
      File.open(@filename, "rb") do |file|
        while part = file.read(8192)
          yield part
        end
      end
    end

    # Filename attribute.
    # Alias is used by some rack servers to detach from Ruby early.
    # @return [String]
    attr_reader :filename
    alias :to_path :filename

    # Was the file in the system and ready to be served?
    def found?
      @status == 200 or @status == 304
    end
  
    # Present the final response for rack.
    # @return (Array)[status, headers, body]
    def finish
      [@status, @headers, @body]
    end
  
  end

end
