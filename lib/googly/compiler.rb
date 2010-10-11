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
      build, type = env["QUERY_STRING"].split('=')
      return not_found unless build
      build = Rack::Utils.unescape(build).gsub /\.(js|log|map)$/, ''
      file_ext = $1
      type = Rack::Utils.unescape(type) if type
      ctx = ctx_setup(build, type)
      compile_js(ctx) if file_ext == 'js'
      filename = ctx[file_ext.to_sym]
      status, headers, body = Rack::File.new(File.dirname(filename)).call(
        {"PATH_INFO" => Rack::Utils.escape(File.basename(filename))}
      )
      if %w{js map}.include? file_ext
        headers["Content-Type"] = "application/javascript" 
      end
      [status, headers, body]
    end
    
    def compile(build, type=nil)
      compile_js(ctx_setup(build, type))
    end
    
    def files(namespaces)
      @source.refresh
      prepare_sources_hash
      files = []
      namespaces.each do |namespace|
        dependencies(namespace).each do |source_info|
          unless files.include? source_info[:filename]
            files.push source_info[:filename] 
          end
        end
      end
      return files if files.length == 0
      files.unshift the_one_true_base_js
      files
    end


    protected
    
    
    def compile_js(ctx)
      # First, test if compilation is really needed.
      compiled = true
      js_mtime = File.mtime ctx[:js] rescue Errno::ENOENT
      makefile_mtime = File.mtime @config.makefile
      compiled = false if !js_mtime or makefile_mtime > js_mtime
      ctx[:files].each do |filename|
        break unless compiled
        mtime = File.mtime filename
        compiled = false if !mtime or mtime > js_mtime
      end
      return if compiled
      # Onward.  Delete the js file and rebuild it.
      File.unlink ctx[:js] rescue Errno::ENOENT
      if ctx[:type] == 'require'
        File.open(ctx[:js], 'w') do |f|
          ctx[:namespaces].each do |namespace|
            f.write "goog.require(#{namespace.dump});\n"
          end
        end
      elsif ctx[:compilation_level] and ctx[:files].length > 0
        File.unlink ctx[:map] rescue Errno::ENOENT
        File.open(ctx[:log], 'w') do |f|
          f.write "Start: #{Time.now}\n\n"
          f.flush
          out, err = @beanshell.compile_js(ctx[:options])
          puts err
          f.write err
          f.write "\nEnd: #{Time.now}\n"
        end
      else # concat
        File.open(ctx[:js], 'w') do |f|
          ctx[:files].each do |filename|
            file = File.read filename
            f.write file
            f.write "\n" unless file =~ /\n\Z/
          end
        end
      end
    end
    
    # Sets up entire context for a compilation.
    # :files => array of all source files in build.
    # :type => computed type.
    # :log,js,map => full path to the files.
    # :namespaces => from the 'require' for the build.
    # :compilation_level => the compiler option, if present.
    # :options => for compiler.jar only; use the above extracted
    #             keys for internal Googly::Compiler logic.
    def ctx_setup(build, type)
      @yaml = nil # so yaml() will reload the file
      if !type or type == 'default'
        if yaml(build)['default']
          type = 'default'
        else
          type = 'require'
        end
      end
      base_filename = File.expand_path("#{build}.#{type}", @config.tmpdir)
      ctx = {
        :files => [],
        :type => type,
        :log => "#{base_filename}.log",
        :namespaces => (yaml(build)['require']||[]).flatten
      }
      if type == 'require'
        ctx[:options] = []
        # file dependency intentionally skipped
      else
        ctx[:options] = yaml(build, type).flatten
        # add namespace files to options
        files(ctx[:namespaces]).each do |filename|
          ctx[:options].push '--js'
          ctx[:options].push filename
        end
      end
      # scan fully built set of options to extract context
      option = nil
      ctx[:options].each do |value|
        option = value and next unless option
        raise "options must all be -- format" unless option =~ /^--/
        if option == '--js'
          ctx[:files].push value
        elsif option == '--js_output_file'
          ctx[:js] = File.expand_path value
          value.replace ctx[:js] # upgrade to full path
        elsif option == '--create_source_map'
          ctx[:map] = File.expand_path value
          value.replace ctx[:map] # upgrade to full path
        elsif option == '--compilation_level'
          ctx[:compilation_level] = File.expand_path value
        end
        option = nil
      end
      # supply default js and map if none were supplied
      unless ctx[:js]
        ctx[:js] = "#{base_filename}.js"
        ctx[:options] << '--js_output_file'
        ctx[:options] << ctx[:js]
      end
      unless ctx[:map]
        ctx[:map] = "#{base_filename}.map" 
        ctx[:options] << '--create_source_map'
        ctx[:options] << ctx[:map]
      end
      ctx
    end
    
    # Returns specified fragment of the yaml file
    # Performs tests to report problems with the yaml file
    # note: @yaml resets on each call to call()
    def yaml(build=nil, type=nil)
      @yaml ||= YAML.load(ERB.new(File.read(@config.makefile)).result)
      raise "makefile error" unless @yaml.kind_of? Hash
      if build
        raise "#{build.dump} not found" unless @yaml.has_key?(build)
        raise "makefile error" unless @yaml[build].kind_of? Hash
        if type
          raise "#{type.dump} in #{build.dump} not found" unless @yaml[build].has_key?(type)
          yaml = @yaml[build][type] || []
          raise "#{type.dump} in #{build.dump} not array" unless yaml.kind_of? Array
          return yaml
        else
          return @yaml[build]
        end
      end
      @yaml
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
    def the_one_true_base_js
      base_js = nil
      @source.deps.each do |filename, dep|
        if File.basename(filename) == 'base.js'
          if dep[:provide].length + dep[:require].length == 0
            if File.read(filename) =~ /^var goog = goog \|\| \{\};/
              if base_js
                raise "Google closure base.js found more than once."
              end
              base_js = filename
            end
          end
        end
      end
      raise "Google closure base.js could not be found" unless base_js
      base_js
    end
    
    # recursive magics
    def dependencies(namespace, deps_list = [], traversal_path = [])
      unless source = @sources[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      if traversal_path.include? namespace
        traversal_path.push namespace
        raise "Circular dependency error. #{traversal_path.join(', ')}.\n"
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