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
  
  # Googly::Route is the primary file server.  It supports ERB and Haml
  # templating.  Templates render with a Rack::Request binding.

  class Route
    
    include Responses

    # @param (String) root Filesystem root.
    # @param (Boolean,String) deps True to vend '/deps.js' or simply the path info you prefer.
    # @param (Source) source Only needed when deps is enabled.
    def initialize(root, deps = false, source = nil)
      @root = root
      @deps = deps
      @deps = '/deps.js' if @deps == true 
      @source = source
    end

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @param (String) path_info Optional param used to avoid unnecessary 
    #                 escaping and unescaping of env["PATH_INFO"].
    # @return (Array)[status, headers, body]
    def call(env, path_info = nil)
      path_info ||= Rack::Utils.unescape(env["PATH_INFO"])
      return forbidden if path_info.include? ".."
      return @source.deps_js if path_info == @deps
      # Static files
      filename = File.join(@root, path_info)
      files = [filename]
      files << filename + '.html' if File.extname(path_info) == ''
      files.each do |filename|
        if File.file?(filename) and File.readable?(filename)
          return file_response(env, filename)
        end
      end
      # Templates files
      Template.new(env, filename).response.finish
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
    
  end
end