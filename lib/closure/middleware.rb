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

  # Although Closure Script can run as an app or in a cascade, most installations
  # will use this {Middleware} configured with Closure.add_source().
  # @example config.ru
  #  require 'closure'
  #  Closure.add_source '../src/myapp', '/myapp'
  #  use Closure::Middleware
  
  class Middleware
    
    # @param (String) home_page File to serve at the root.  Handy for stand-alone projects.
    #   You can use a Closure Script, even in non-source folders, by using the url extension
    #   e.g. 'index.html' instead of the actual filename 'index.haml'.
    def initialize(app, home_page=nil)
      @app = app
      @server = ShowExceptions.new(Server.new(Closure.sources, home_page))
    end

    def call(env)
      status, headers, body = @server.call(env)
      return @app.call(env) if headers["X-Cascade"] == "pass"
      [status, headers, body]
    end

  end
  
end
