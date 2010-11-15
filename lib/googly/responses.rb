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
  
  # Standard rack responses shared amongst everything Googly.
  
  module Responses

    # Used with {Responses#file_response}.
    # This has all known tricks for serving from the filesystem.
    class FileResponseBody
      def initialize(filename)
        @filename = filename
      end
      def each
        File.open(@filename, "rb") { |file|
          while part = file.read(8192)
            yield part
          end
        }
      end
      attr_reader :filename
      alias :to_path :filename
    end
    
    # Status 200 directly from the filesystem. 
    # Includes caching optimized for development.
    # Return {#not_found} if filename isn't a readable file.
    # Return {#not_modified} if File.mtime == If-Modified-Since.
    # @return (Array)[status, headers, FileResponseBody]
    def file_response(env, filename, content_type = nil)
      begin
        raise Errno::EPERM unless File.file?(filename) and File.readable?(filename)
      rescue SystemCallError
        return not_found
      end
      if size = File.size?(filename)
        body = FileResponseBody.new(filename)
      else
        body = [File.read(filename)]
        size = body.first.respond_to?(:bytesize) ? body.first.bytesize : body.first.size
      end
      # Caching strategy
      if_mod_since = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE']) rescue nil
      if env['QUERY_STRING'] =~ /^[0-9]{9,10}$/
        # Files timestamped with unix time in QUERY_STRING are supercharged
        last_modified = Time.now
        cache_control = 'max-age=86400, public' # one day
        return not_modified if if_mod_since and File.mtime(filename) == Time.at(env['QUERY_STRING'].to_i)
      else
        # Regular files must always revalidate with timestamp
        last_modified = File.mtime(filename)
        cache_control = 'max-age=0, private, must-revalidate'
        return not_modified if last_modified == if_mod_since
      end
      
      [200, {
        "Content-Type"   => content_type || Rack::Mime.mime_type(File.extname(filename), 'text/plain'),
        "Content-Length" => size.to_s,
        "Last-Modified"  => last_modified.httpdate,
        "Cache-Control" => cache_control
      }, body]
    end
    module_function :file_response

    # Status 304
    # @return (Array)[status, headers, body]
    def not_modified
      [304, {}, []]
    end
    module_function :not_modified
    
    # Status 403 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def forbidden
      body = "403 Forbidden\n"
      [403, {"Content-Type" => "text/plain",
             "Content-Length" => body.size.to_s,
             "X-Cascade" => "pass"},
       [body]]
    end
    module_function :forbidden

    # Status 404 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def not_found
      body = "404 Not Found\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
    module_function :not_found
        
  end
end