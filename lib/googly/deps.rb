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
  
  # The deps server will vend a deps.js that is always up-to-date.

  class Deps

    include Googly::Responses

    # @param (Source) source
    # @param (String) path_info default: '/deps.js'
    def initialize(source, path_info)
      @source = source
      @path_info = path_info
      @path_info = '/deps.js' if @path_info == true 
    end
    
    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      if Rack::Utils.unescape(env["PATH_INFO"]) == @path_info
        deps
      else
        not_found
      end
    end
    
    protected
    
    def deps
      @deps_js = nil if @source.deps_changed?
      unless @deps_js
        @deps_js = []
        @deps_js << "// This deps.js was brought to you by Googlyscript\n"
        @deps_js << "goog.basePath = '';\n"
        @source.deps.sort{|a,b|a[1][:path]<=>b[1][:path]}.each do |filename, dep|
          @deps_js << "goog.addDependency(#{dep[:path].inspect}, #{dep[:provide].inspect}, #{dep[:require].inspect});\n"
        end
        @deps_content_length = @deps_js.inject(0){|sum, s| sum + s.length }.to_s
      end
      # Respond
      [200, {"Content-Type" => "text/javascript",
         "Content-Length" => @deps_content_length},
        @deps_js]
    end
    
  end
  
end