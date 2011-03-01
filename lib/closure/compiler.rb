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
  
  class Compiler
    
    class Error < StandardError
    end
    
    class Compilation
      attr_accessor :log

      # @private api work in progress
      attr_reader :js_output_file
      
      # @private
      def initialize(javascript, js_output_file, log, env)
        @javascript = [javascript]
        @js_output_file = js_output_file
        @log = log
        @env = env
      end
      
      # @private deprecated
      def to_response_with_console
        response = to_response
        if response.class == Rack::Response
          msg = "#to_response_with_console deprecated, use #to_response"
          response.write "try{console.warn(#{msg.dump})}catch(err){};\n"
        end
        response
      end

      # Turn the compiled javascript into a Rack::Response object.
      # Success and warning messages, which aren't raised like errors,
      # will be logged to the javascript console.
      # @example
      #   <% @response = goog.compile(args).to_response %>
      # @return (Rack::Response)
      def to_response
        if !log and @js_output_file
          response = FileResponse.new @env, @js_output_file, 'application/javascript'
        else
          response = Rack::Response.new
          response.headers['Content-Type'] = 'application/javascript'
          response.headers["Cache-Control"] = 'max-age=0, private, must-revalidate'
          if log
            consolable_log = '"Closure Compiler: %s\n\n", ' + log.rstrip.dump
            if log.split("\n").first =~ / 0 warn/i
              response.write "try{console.log(#{consolable_log})}catch(err){};\n"
            else
              response.write "try{console.warn(#{consolable_log})}catch(err){};\n"
            end
          end
          javascript.each {|js| response.write js }
        end
        response
      end
      
      # @private api work in progress
      def <<(js)
        if @js_output_file
          @javascript << File.read(@js_output_file) rescue ''
          @js_output_file = nil
        end
        @javascript << js
      end

      # Always returns the compiled javascript (possibly an empty string).
      # @example
      #   <%= goog.compile(args) %>
      def javascript
        if @js_output_file
          File.read(@js_output_file) rescue ''
        else
          @javascript.join(nil)
        end
      end
      alias :to_s :javascript
      
    end
    
    # Java won't let you change working directories and the Closure Compiler
    # doesn't allow setting a base path.  No problem, we can do it.
    
    # These are filename options and will be expanded to a new base.
    # If supplied as arguments, output options are available as instance
    # variables and attributes that have been expanded to the new base.
    OUTPUT_OPTIONS = %w{
      --js_output_file
      --create_source_map
      --output_manifest
      --property_map_output_file
      --variable_map_output_file
      --module_output_path_prefix
    }
    
    # These are filename options and will be expanded to a new base.
    # These will have their modification times checked against js_output_file.
    INPUT_OPTIONS = %w{
      --js
      --externs
      --property_map_input_file
      --variable_map_input_file
    }
    
    # Compile Javascript. Checks file modification times
    # but does not support namespaces like {Goog#compile} does.
    # @param (Array) args Arguments for the compiler.
    # @param (Array) dependencies Any other files to check mtime on, like makefiles.
    # @param (String) base All filenames will be expanded to this location.
    # @param (Hash) env Rack environment.  Supply if you want a response that is cacheable.
    def self.compile(args, dependencies = [], base = nil, env = {})
      args = args.collect {|a| a.to_s } # for bools and numerics
      files = []
      js_output_file = nil
      # Scan to expand paths and extend self with output options
      args_index = 0
      while args_index < args.length
        option, value = args[args_index, 2]
        value = File.expand_path(value, base) if base
        if INPUT_OPTIONS.include?(option)
          files << args[args_index+1] = value
        end
        if OUTPUT_OPTIONS.include?(option)
          js_output_file = value if option == '--js_output_file'
          args[args_index+1] = value
        end
        args_index = args_index + 2
      end
      if files.empty?
        # otherwise java locks up waiting for stdin
        return Compilation.new '', nil, nil, env
      end
      # We don't bother compiling if we can detect that no sources were modified
      if js_output_file
        js_mtime = File.mtime js_output_file rescue Errno::ENOENT
        compiled = !!File.size?(js_output_file) # catches empty files too
        (files + dependencies).each do |filename|
          break unless compiled
          mtime = File.mtime filename
          compiled = false if !mtime or mtime > js_mtime
        end
        if compiled
          return Compilation.new '', js_output_file, nil, env
        end
        File.unlink js_output_file rescue Errno::ENOENT
      end
      stdout, log = Closure.run_java Closure.config.compiler_jar, 'com.google.javascript.jscomp.CommandLineRunner', args
      if log.empty?
        log = nil
      else
        # Totals at the end make sense for the command line.  But at
        # the start makes more sense for html and the Javascript console
        split_log = log.split("\n")
        if split_log.last =~ /^\d+ err/i
          error_message = split_log.pop
        else
          error_message = split_log.shift
        end
        if split_log.empty?
          log = error_message
        else
          log = error_message + "\n\n" + split_log.join("\n")
        end
        raise Error, log unless error_message =~ /^0 err/i
      end
      Compilation.new stdout, js_output_file, log, env
    end
    
    
    # @private api work in progress
    def self.module_info(mods)
      js = "var MODULE_INFO = {"
      js += mods.map do |name, options|
        # p options
        reqs = options[:requires].map{ |r| r.dump }
        s = "#{name.dump}: [#{reqs.join ', '}]"
      end.join ', '
      js += "};\n"
    end


    # @private api work in progress
    def self.module_raw_uris(mods, sources)
      js = "var MODULE_URIS = {\n"
      js += mods.map do |name, options|
        files = options[:files].map{ |r| (sources.src_for r).dump }
        s = "#{name.dump}: [\n#{files.join ",\n"}]"
      end.join ",\n"
      js += "\n};\n"
    end
    
    
    # @private api work in progress
    def self.module_compiled_uris(mods, sources, prefix)
      js = "var MODULE_URIS = {\n"
      js += mods.map do |name, options|
        file = sources.src_for prefix + name + '.js'
        s = "#{name.dump}: [#{file.dump}]"
      end.join ",\n"
      js += "\n};\n"
    end
  
  
    # @private api work in progress
    def self.modulize(args)
      found_starred = false
      found_numeric = false
      js_files = []
      mods = []
      args_index = args.length
      while args_index > 0
        args_index = args_index - 2
        option, value = args[args_index, 2]
        if option == '--js'
          js_files.unshift value
        elsif option == '--module'
          if js_files.empty?
            raise "No --js files for module #{value}" 
          end
          mod = value.split ':'
          if mod[1] == '*'
            mod[1] = js_files.size 
            found_starred = true
          else
            found_numeric = true
          end
          # mods.unshift mod
          mods.unshift [mod[0], {
            :requires => mod[2..-1],
            :files => js_files
          }]
          js_files = []
          args[args_index+1] = mod.join ':'
        end
      end
      unless js_files.empty? or mods.empty?
        raise 'Automatic --module must appear before first --js option.'
      end
      if found_starred and found_numeric
        raise 'Static and automatic --module options can not be mixed.'
      end
      mods
    end

  end
  
end
