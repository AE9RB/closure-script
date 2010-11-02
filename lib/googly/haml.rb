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

  # To enable Haml, install the gem and it becomes available.
  # @example config.ru
  #  Googly.config.haml[:format] = :html5

  class Haml
    
    include Responses

    # @param (String) root Filesystem root.
    def initialize(root)
      @root = root
    end

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      
      path_info = Rack::Utils.unescape(env["PATH_INFO"])

      return forbidden if path_info.include? ".."
      
      template = Errno::ENOENT
      filename = path_info.gsub(/\.html$/, '.haml')
      if filename != path_info
        filename = File.join(@root, filename)
        template = File.read(filename) rescue Errno::ENOENT
      end
      if template == Errno::ENOENT
        filename = File.join(@root, path_info + '.haml')
        template = File.read(filename) rescue Errno::ENOENT
      end
      if template == Errno::ENOENT
        filename = File.join(@root, path_info + '.html.haml')
        template = File.read(filename) rescue Errno::ENOENT
      end
      return not_found if template == Errno::ENOENT
      
      require 'haml'
      options = Googly.config.haml.merge(:filename => filename)
      body = ::Haml::Engine.new(template, options).render
      [200, {"Content-Type" => "text/html",
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
  end
end
