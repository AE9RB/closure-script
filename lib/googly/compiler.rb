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
  
  # The compiler will detect changes to your source and compile only
  # when necessary.

  class Compiler
    
    def initialize(source, config)
      @source = source
      #TODO remove config after makefile extraction
      @config = config
    end

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      build, type = env["QUERY_STRING"].split('=')
      return Googly.not_found unless build
      build = Rack::Utils.unescape(build).gsub(/\.(js|log|map)$/, '')
      return Googly.not_found unless file_ext = $1
      type = Rack::Utils.unescape(type) if type
      ctx = setup(build, type)
      compile(ctx, env) if file_ext == 'js'
      filename = ctx[file_ext.to_sym]
      content_type = %w{js map}.include?(file_ext) ? 'application/javascript' : 'text/plain'
      FileResponse.new(env, filename, content_type).finish
    end
    
    protected
    
    
    def compile(ctx, env)
      makefile_mtime = File.mtime @config.makefile
      js_mtime = File.mtime ctx[:js] rescue Errno::ENOENT
      compiled = js_mtime && js_mtime > makefile_mtime
      # the 'require' type is unique
      if ctx[:type] == 'require'
        unless compiled
          File.open(ctx[:js], 'w') do |f|
            ctx[:namespaces].each do |namespace|
              f.write "goog.require(#{namespace.dump});\n"
            end
          end
        end
        return
      end
      # compute namespace additions to files and options
      files = @source.files(ctx[:namespaces], env)
      options = files.inject([]) do |memo, filename|
        memo.push '--js'
        memo.push filename
      end
      # The namespace files always come first for base.js
      files = files + ctx[:files]
      options = options + ctx[:options]
      # update compiled status with scan of files and externs
      (files + ctx[:externs]).each do |filename|
        break unless compiled
        mtime = File.mtime filename
        compiled = false if !mtime or mtime > js_mtime
      end
      return if compiled
      # compile
      if ctx[:compilation_level] and files.length > 0
        File.unlink ctx[:js] rescue Errno::ENOENT
        File.unlink ctx[:map] rescue Errno::ENOENT
        File.open(ctx[:log], 'w') do |f|
          f.write "Start: #{Time.now}\n\n"
          f.flush
          java_opts = options.collect{|a|a.to_s.dump}.join(', ')
          out, err = Googly.java("Googly.compile_js(new String[]{#{java_opts}});")
          puts err
          f.write err
          f.write "\nEnd: #{Time.now}\n"
        end
      else # concat
        File.open(ctx[:js], 'w') do |f|
          files.each do |filename|
            file = File.read filename
            f.write file
            f.write "\n" unless file =~ /\n\Z/
          end
        end
      end
    end
    
    
    # Sets up entire context for a compilation.
    # :files => array of all source files in build.
    # :externs => array of all externs in build.
    # :type => computed type.
    # :log,js,map => full path to the files.
    # :namespaces => from the 'require' for the build.
    # :compilation_level => the compiler option, if present.
    # :options => for compiler.jar only
    def setup(build, type)
      #TODO new makefile system
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
        :options => (type == 'require') ? [] : yaml(build, type).flatten,
        :files => [],
        :externs => [],
        :type => type,
        :log => "#{base_filename}.log",
        :namespaces => (yaml(build)['require']||[]).flatten
      }
      # scan fully built set of options to extract context
      option = nil
      ctx[:options].each do |value|
        option = value and next unless option
        raise "options must all be -- format" unless option =~ /^--/
        case option
          when '--js'
            ctx[:files].push value
          when '--externs'
            ctx[:externs].push value
          when '--js_output_file'
            ctx[:js] = File.expand_path value
            value.replace ctx[:js] # sync to full path
          when '--create_source_map'
            ctx[:map] = File.expand_path value
            value.replace ctx[:map] # sync to full path
          when '--compilation_level'
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
    # note: @yaml resets on each call to #setup
    def yaml(build=nil, type=nil)
      raise "no makefile configured" unless @config.makefile
      require 'yaml'
      @yaml ||= ::YAML.load(ERB.new(File.read(@config.makefile)).result)
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


  end
  
end
