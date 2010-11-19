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
  
  class Compilation
    
    # Java won't let you change working directories and the Closure Compiler
    # doesn't allow setting a base path.  If a new base path is specified,
    # these options are expanded there.  Except for js and externs, each
    # of these are available as instance variables and accessors when
    # supplied in the arguments.
    FILE_OPTIONS = %w{
      --create_source_map
      --externs
      --js
      --js_output_file
      --output_manifest
      --property_map_input_file
      --property_map_output_file
      --variable_map_input_file
      --variable_map_output_file
    }
    
    #TODO the --module option is really hard to use no matter what the tools.
    # We could probably make it namespace-friendly by allowing a substitution of
    # the file count to mean "the number of files up to this point since last time"
    # --js file --ns namesp --module app:# --ns goog.editor --module edit:#:app

    # @param (String) args Arguments for the compiler.
    # @param (String) deps {Deps} instance for your source scripts.
    # @param (String) others Any other files to check mtime on, like makefiles.
    # @param (String) base All filenames will be expanded to this location.
    # @param (String) env Rack environment.
    def initialize(args, deps, others = [], base=nil, env={})
      @args = Array.new args
      @env = env
      js = []
      extras = []
      # Scan to expand paths and extract critical options
      args_index = 0
      while args_index < args.length
        option, value = @args[args_index, 2]
        if FILE_OPTIONS.include? option
          value = @args[args_index+1] = File.expand_path(*[value, base].compact)
          unless %w{--externs --js}.include? option
            var_name = option.sub(/^--/, '')
            instance_variable_set "@#{var_name}", value
            eval "def self.#{var_name}; @#{var_name}; end"
          end
        end
        case option
          when '--js'
            js.push value
          when '--externs', '--property_map_input_file', '--variable_map_input_file'
            extras.push value
          when '--compilation_level'
            @compilation_level = value
        end
        args_index = args_index + 2
      end
      # Cleanly insert namespace files
      ns = []
      ns_index = 0
      args_index = 0
      while args_index < args.length
        option, value = @args[args_index, 2]
        if option == '--ns'
          deps.files(value, env, ns)
          replacement = []
          while ns_index < ns.length
            cur_ns = ns[ns_index]
            unless js.include? cur_ns
              js.push cur_ns
              replacement.push '--js'
              replacement.push cur_ns
            end
            ns_index = ns_index + 1
          end
          @args[args_index, 2] = replacement
        end
        args_index = args_index + 2
      end
      # We won't bother compiling if the output file is newer than all sources
      if @js_output_file
        js_mtime = File.mtime @js_output_file rescue Errno::ENOENT
        compiled = !!File.size?(@js_output_file) # catches empty files too
        (js + extras + others).each do |filename|
          break unless compiled
          mtime = File.mtime filename
          compiled = false if !mtime or mtime > js_mtime
        end
        return if compiled
        File.unlink @js_output_file rescue Errno::ENOENT
      end
      # Do it
      java_opts = @args.collect{|a|a.to_s.dump}.join(', ')
      @stdout, @stderr = Googly.java("Googly.compile_js(new String[]{#{java_opts}});")
    end
    
    # Allows easy http caching of the js_output_file.  In templates:
    # <% @response = compile(args).to_response %> is preferred over <%= compile(args) %>.
    # @return (FileResponse) 
    def to_response
      FileResponse.new @env, js_output_file, 'application/javascript'
    end

    # Always returns the compiled javascript, or possibly an empty string.
    def javascript
      if @js_output_file
        File.read(@js_output_file) rescue ''
      else
        @stdout
      end
    end
    alias :to_s :javascript
    
    # Results from compiler.jar.  If you didn't specify a --js_output_file
    # then this will be the compiled script.  Otherwise, it's usually empty
    # but may contain output depending on the arguments.
    attr_reader :stdout
    
    # Results from compiler.jar.  The log, when there is one, is found here.
    # Use `--summary_detail_level 3` to see log when no errors or warnings.
    attr_reader :stderr
    
    # Compiler arguments after fixups.  Use to inspect the actual
    # arguments passed to compiler.jar.
    attr_reader :args
    
  end
  
end
