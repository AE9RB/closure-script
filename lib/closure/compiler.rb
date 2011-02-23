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
    
    # Java won't let you change working directories and the Closure Compiler
    # doesn't allow setting a base path.  No problem, we can do it.
    
    # These are filename options and will be expanded to a new base.
    # If supplied as arguments, output options are available as instance
    # variables and attributes that have been expanded to the new base.
    OUTPUT_OPTIONS = %w{
      --create_source_map
      --js_output_file
      --output_manifest
      --property_map_output_file
      --variable_map_output_file
    }
    
    # These are filename options and will be expanded to a new base.
    # These will have their modification times checked against js_output_file.
    INPUT_OPTIONS = %w{
      --js
      --externs
      --property_map_input_file
      --variable_map_input_file
    }
    
    #TODO upgrade Compiler to use the same middleware pattern as Templates
    # self.compile should maybe return a new Compilation object
    
    # Instantiating will perform compilation.  It will check file modification times
    # but does not support namespaces like {Goog#compile} does.
    # @param (Array) args Arguments for the compiler.
    # @param (Array) dependencies Any other files to check mtime on, like makefiles.
    # @param (String) base All filenames will be expanded to this location.
    # @param (Hash) env Rack environment.  Supply if you want a response that is cacheable
    #  and for {Templates} errors to be processed.
    def initialize(args, dependencies = [], base = nil, env = {})
      @env = env
      return if args.empty? # otherwise java locks up
      args = args.collect {|a| a.to_s } # for bools and numerics
      files = []
      # Scan to expand paths and extend self with output options
      args_index = 0
      while args_index < args.length
        option, value = args[args_index, 2]
        value = File.expand_path(value, base) if base
        if INPUT_OPTIONS.include?(option)
          files << args[args_index+1] = value
        end
        if OUTPUT_OPTIONS.include?(option)
          var_name = option.sub(/^--/, '')
          instance_variable_set "@#{var_name}", args[args_index+1] = value
          eval "def self.#{var_name}; @#{var_name}; end"
        end
        args_index = args_index + 2
      end
      # We don't bother compiling if we can detect that no sources were modified
      if @js_output_file
        js_mtime = File.mtime @js_output_file rescue Errno::ENOENT
        compiled = !!File.size?(@js_output_file) # catches empty files too
        (files + dependencies).each do |filename|
          break unless compiled
          mtime = File.mtime filename
          compiled = false if !mtime or mtime > js_mtime
        end
        return if compiled
        File.unlink @js_output_file rescue Errno::ENOENT
      end
      @stdout, @stderr = Closure.run_java Closure.config.compiler_jar, 'com.google.javascript.jscomp.CommandLineRunner', args
      @log = stderr
      if !log.empty?
        # Totals at the end make sense for the command line.  But at
        # the start makes more sense for html and the Javascript console
        split_log = log.split("\n")
        if split_log.last =~ /^\d+ err/i
          error_message = split_log.pop
        else
          error_message = split_log.shift
        end
        if split_log.empty?
          @log = error_message
        else
          @log = error_message + "\n\n" + split_log.join("\n")
        end
        raise Error, log unless error_message =~ /^0 err/i
      end
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
        response.write javascript
      elsif @js_output_file
        response = FileResponse.new @env, @js_output_file, 'application/javascript'
      else
        response.write javascript
        response
      end
      response
    end

    # Always returns the compiled javascript (possibly an empty string).
    # @example
    #   <%= goog.compile(args) %>
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
    # If nil, compilation was skipped because js_output_file was up to date.
    attr_accessor :stdout
    
    # Results from compiler.jar.  The raw log, when there is one, is found here.
    # Use `--summary_detail_level 3` to see log when no errors or warnings.
    # If nil, compilation was skipped because js_output_file was up to date.
    attr_accessor :stderr

    # Results from compiler.jar. Contains the processed log file ordered
    # for display in a web browser instead of the command line.
    # Use `--summary_detail_level 3` to force a log when compilation
    # generates no errors or warnings.
    # If nil, compilation was skipped because js_output_file was up to date.
    attr_accessor :log

  end
  
end
