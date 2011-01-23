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

require 'tempfile'

class Googly
  
  # Templates render with an instance named goog in the context.
  
  class Goog
    
    def initialize(env, sources, render_stack)
      @sources = sources
      @env = env
      @render_stack = render_stack
      @dependencies = []
    end
    
    # You can add additional files to have their mtimes scanned.
    # Perhaps you want to use a .yml file to define build options.
    # Googly::Template calls this for every render so you don't need
    # to define compiler arguments in the same template that calls compile.
    def add_dependency(dependency)
      dependency = File.expand_path dependency, @render_stack.last
      @dependencies << dependency unless @dependencies.include? dependency
    end

    # Run a compiler job.  Accepts every argument that compiler.jar supports.
    # Accepts new `--ns namespace` option which literally expands into
    # `--js filename` arguments in place to satisfy the namespace.
    # If you specify a --js_output_file then the compiler will check File.mtime
    # on every source file plus all the templates and skip the compilation
    # if the js_output_file is newest.
    # Paths are relative to the template calling #compile.
    # @example myapp.js.erb
    #   <% @response = goog.compile(%w{
    #     --js_output_file ../public/myapp.js
    #     --ns myapp.HelloWorld
    #     --compilation_level ADVANCED_OPTIMIZATIONS
    #   }).to_response_with_console %>
    # @param [Array<String>] args
    # @return [Compilation]
    def compile(args)
      args = Array.new args
      files = []
      files_index = 0
      args_index = 0
      comp = Compilation.new @env
      deps_js = Tempfile.new 'googlyscript_deps_js'
      has_externs = false
      begin
        while args_index < args.length
          option, value = args[args_index, 2]
          if option == '--ns'
            files_for(value, files)
            replacement = []
            while files_index < files.length
              if files[files_index] =~ /\.externs$/
                has_externs = true
                replacement.push '--externs'
              else
                replacement.push '--js'
              end
              replacement.push files[files_index]
              files_index = files_index + 1
            end
            args[args_index, 2] = replacement
          else
            args_index = args_index + 2
          end
        end
        if has_externs
          # We need to compile with a copy of deps.js
          # to pick up the goog.provides for externs.
          # File mtime is rolled back to not trigger compilation.
          deps_js.open
          @sources.deps_response(@env).each do |s|
            deps_js.write s
          end
          deps_js.close
          File.utime(Time.now, Time.at(0), deps_js.path)
          args.unshift deps_js.path
          args.unshift '--js'
        end
        comp.compile_js args, File.dirname(@render_stack.last), @dependencies
      rescue Exception => e
        # Namespace problems are Ruby exceptions
        comp.stderr = "#{e.inspect}\n\n1 error(s)"
      ensure
        deps_js.unlink
      end
      comp
    end

    # Calculate files needed to satisfy a namespace.
    # This will be especially useful for module generation.
    # If you pass the filenames returned from last run,
    # additional files (if any) will be appended to satisfy
    # the new namespace.
    # @example cal_file_list.erb
    #  <%= goog.files_for %w{myapp.Calendar} %>
    # @return (Array)
    def files_for(namespace, filenames=nil)
      @sources.files_for(@env, namespace, filenames)
    end

    # The Google Closure base.js script.
    # If you use this instead of a static link, you are free to relocate relative
    # to the Google Closure library without updating every html fixture page.
    # Unfortunately, the better caching can't be used because of the way
    # base.js explores the DOM looking for where to load deps.js.
    # @example view_test.erb
    #  <script src="<%= goog.base_js %>"></script>
    def base_js
      @sources.base_js(@env)
    end
    
    # This is where base.js looks to find deps.js by default.  You will always
    # be served a Googlyscript generated deps.js from this location.
    def deps_js
      @sources.deps_js(@env)
    end

    # You can serve a deps.js from anywhere you want to drop a template.
    # @example deps.jazz.erb
    #  <% @response = goog.deps_response %>
    # @return (Rack::Response)
    def deps_response
      @sources.deps_response(@env, File.dirname(Rack::Utils.unescape(@env["PATH_INFO"])))
    end
    
  end
  
end
