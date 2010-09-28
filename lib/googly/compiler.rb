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

  class Compiler
    
    include Googly::Responses    
    
    def initialize(source, beanshell, config)
      @source = source
      @beanshell = beanshell
      @config = config
    end

    def call(env)
      yaml = YAML.load(ERB.new(File.read(@config.makefile)).result)
      build, type = env["QUERY_STRING"].split('=')
      #TODO .js is hardcoded
      build = Rack::Utils.unescape(build).gsub /\.js$/, ''
      #TODO calc default type, either 'require' or solo type
      type = Rack::Utils.unescape(type||'test') 
      #TODO figure out something to help find yaml mistakes
      raise "makefile error" unless yaml.kind_of? Hash
      raise "makefile error" unless yaml[build].kind_of? Hash
      raise "makefile error" unless yaml[build][type].kind_of? Array
      
      namespaces = (yaml[build]['require']||[]).flatten
      options = yaml[build][type].flatten
      output = compile_js(namespaces, options)
      
      #TODO temp logging
      puts output
      
      #TODO use Rack::File and real js_output_file
      body = File.read File.join(Googly.base_path, 'app', 'javascripts', 'out.js')
      [404, {"Content-Type" => "text/javascript",
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
    def compile_js(namespaces, options)
      options.push '--js_output_file'
      options.push File.join(Googly.base_path, 'app', 'javascripts', 'out.js')
      files(namespaces).each do |filename|
        options.push '--js'
        options.push filename
      end
      @beanshell.compile_js(options)
    end

    def files(namespaces)
      refresh
      files = [@base_js]
      namespaces.each do |namespace|
        dependencies(namespace).each do |source_info|
          unless files.include? source_info[:filename]
            files.push source_info[:filename] 
          end
        end
      end
      files
    end

    protected
    
    def refresh
      @source.refresh
      prepare_sources_hash
      find_the_one_true_base_js
    end
    
    # The deps from Googly::Source are optimized for scanning the filesystem
    # and serving up deps.js.  This creates a new hash optimized for making a
    # dependency graph; one keyed by the provide instead of the filename.
    def prepare_sources_hash
      @sources = {}
      @source.deps.each do |filename, dep|
        dep[:provide].each do |provide|
          if @sources[provide]
            raise "Namespace #{provide.dump} provided more than once."
          end
          @sources[provide] = {
            :filename => filename,
            :require => dep[:require]
          }
        end
      end
    end
    
    # Looks for a single file named base.js without
    # any requires or provides that defines var goog inside.
    # This is how the original python scripts did it
    # except I added the provide+require check.
    def find_the_one_true_base_js
      @base_js = nil
      @source.deps.each do |filename, dep|
        if File.basename(filename) == 'base.js'
          if dep[:provide].length + dep[:require].length == 0
            if File.read(filename) =~ /^var goog = goog \|\| \{\};/
              if @base_js
                raise "Google closure base.js found more than once"
              end
              @base_js = filename
            end
          end
        end
      end
      raise "Google closure base.js could not be found" unless @base_js
    end
    
    def dependencies(namespace, deps_list = [], traversal_path = [])
      unless source = @sources[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      if traversal_path.include? namespace
        traversal_path.push namespace
        raise "Circular dependency error. #{traversal_path.join(', ')}\n"
      end
      traversal_path.push namespace
      source[:require].each do |required|
        dependencies required, deps_list, traversal_path
      end
      traversal_path.pop
      deps_list.push source
      return deps_list
    end


  end
  
end