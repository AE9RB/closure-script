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
  
  class Server
    
    def initialize(sources, home_page = nil)
      @sources = sources
      @home_page = home_page
    end
    
    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      path_info = Rack::Utils.unescape(env["PATH_INFO"])
      return not_found if path_info.include? ".." # unsafe
      # Stand-alone projects will find this useful
      if @home_page and path_info == '/'
        response = FileResponse.new(env, @home_page)
        response = Template.new(env, @sources, @home_page).response unless response.found?
        return response.finish
      end
      # Replace the deps.js in detected Closure Library
      begin
        if path_info == @sources.deps_js(env)
          return @sources.deps_response(env).finish
        end
      rescue ClosureBaseNotFoundError
      end
      # Then check all the sources
      @sources.each do |path, dir|
        if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
          filename = File.join(dir, $1)
          response = FileResponse.new(env, filename)
          if !response.found? and File.extname(path_info) == ''
            response = FileResponse.new(env, filename + '.html')
          end
          response = Template.new(env, @sources, filename).response unless response.found?
          return response.finish
        end
      end
      not_found
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
