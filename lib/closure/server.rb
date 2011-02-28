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

  # The Closure Script rack server.  There is {Closure::Middleware} available too.
  # @example config.ru
  #  require 'closure'
  #  sources = Closure::Sources.new
  #  sources.add '/myapp', '../src'
  #  run Closure::Server.new sources
  
  class Server
    
    # @param (Sources) sources An instance configured with your scripts.
    # @param (home_page) home_page Optional file or closure-script to serve as root.
    def initialize(sources, home_page = nil)
      @sources = sources
      @home_page = home_page
      @working_dir = Dir.getwd
    end
    
    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      path_info = Rack::Utils.unescape(env['PATH_INFO'])
      return not_found if path_info.include? '..' # unsafe
      # Stand-alone projects will find this useful
      if @home_page and path_info == '/'
        Dir.chdir @working_dir
        response = FileResponse.new(env, @home_page)
        response = Script.new(env, @sources, @home_page).response unless response.found?
        if response.header["X-Cascade"] == "pass"
          if ENV["CLOSURE_SCRIPT_WELCOME"]
            welcome = File.join Closure.base_path, 'scripts', 'welcome'
            response = Script.new(env, @sources, welcome).response
          end
        end
        return response.finish
      end
      # Usurp the deps.js in detected Closure Library
      begin
        if path_info == @sources.deps_js(env)
          return @sources.deps_response(File.dirname(path_info), env).finish
        end
      rescue Sources::BaseJsNotFoundError
      end
      # Then check all the sources
      @sources.each do |dir, path|
        next unless path
        if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
          Dir.chdir @working_dir
          filename = File.join(dir, $1)
          response = FileResponse.new(env, filename)
          if !response.found? and File.extname(path_info) == ''
            response = FileResponse.new(env, filename + '.html')
          end
          response = Script.new(env, @sources, filename).response unless response.found?
          return response.finish
        end
      end
      not_found
    end
    
    private
    
    # Status 404 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def not_found
      return @not_found if @not_found
      body = "404 Not Found\n"
      @not_found = [404, {'Content-Type' => 'text/plain',
             'Content-Length' => body.size.to_s,
             'X-Cascade' => 'pass'},
       [body]]
      @not_found
    end

  end
  
end
