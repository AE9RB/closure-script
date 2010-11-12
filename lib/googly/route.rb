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
      return deps if path_info == @deps
      ext = File.extname(path_info)
      filename = File.join(@root, path_info)
      # First, the static files
      files1 = [filename]
      files1 << filename + '.html' if ext == ''
      files1.each do |filename1|
        if File.file?(filename1) and File.readable?(filename1)
          return file_response(env, filename1)
        end
      end
      # Now the template files
      files1 << filename.gsub(/.html$/,'') if ext == '.html'
      files1.each do |filename1|
        [['.erb', :erb], ['.haml', :haml]].each do |ext, method|
          files2 = [filename1+ext]
          files2 << filename1.gsub(/.html$/, ext) if File.extname(filename1) == '.html'
          files2.each do |filename2|
            if File.file?(filename2) and File.readable?(filename2)
              return send(method, filename2, File.extname(filename1), env)
            end
          end
        end
      end
      not_found
    end
    
    protected
    
    #TODO Rack::Response

    def erb(filename, ext, env)
      require 'erb'
      ctx = Rack::Request.new(env)
      body = ::ERB.new(File.read(filename)).result(ctx.send(:binding))
      [200, {"Content-Type" => Rack::Mime.mime_type(ext, 'text/html'),
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
    
    def haml(filename, ext, env)
      require 'haml'
      options = Googly.config.haml.merge(:filename => filename)
      body = ::Haml::Engine.new(File.read(filename), options).render(Rack::Request.new(env))
      [200, {"Content-Type" => "text/html",
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
    
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
      [200, {"Content-Type" => "text/javascript",
         "Content-Length" => @deps_content_length},
        @deps_js]
    end

  end
end