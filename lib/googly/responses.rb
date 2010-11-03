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
    # Return {#not_found} if filename isn't a readable file.
    # @return (Array)[status, headers, FileResponseBody]
    def file_response(filename, content_type = nil)
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
      [200, {
        "Last-Modified"  => File.mtime(filename).httpdate,
        "Content-Type"   => content_type || Rack::Mime.mime_type(File.extname(filename), 'text/plain'),
        "Content-Length" => size.to_s
      }, body]
    end
    
    # Status 403 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def forbidden
      body = "403 Forbidden\n"
      [403, {"Content-Type" => "text/plain",
             "Content-Length" => body.size.to_s,
             "X-Cascade" => "pass"},
       [body]]
    end

    # Status 404 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def not_found
      body = "404 Not Found\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
        
  end
end