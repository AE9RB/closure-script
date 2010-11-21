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
    #   <% @response = compile(%w{
    #     --js_output_file ../public/myapp.js
    #     --ns myapp.HelloWorld
    #     --compilation_level ADVANCED_OPTIMIZATIONS
    #   }).to_response %>
    # @param [Array<String>] args
    # @return [Compilation]
    def compile(args)
      args = Array.new args
      files = []
      files_index = 0
      args_index = 0
      while args_index < args.length
        option, value = args[args_index, 2]
        if option == '--ns'
          files_for(value, files)
          replacement = []
          while files_index < files.length
            replacement.push '--js'
            replacement.push files[files_index]
            files_index = files_index + 1
          end
          args[args_index, 2] = replacement
        end
        args_index = args_index + 2
      end
      Compilation.new(args,
                      File.dirname(@render_stack.last),
                      @dependencies,
                      @env)
    end

    # Calculate files needed to satisfy a namespace.
    def files_for(namespaces, filenames=nil)
      @sources.files_for(@env, namespaces, filenames)
    end

    # The Google Closure base.js script.
    # If you use this instead of a static link, you are free to relocate relative
    # to the Google Closure library without updating every html fixture page.
    # Unfortunately, the better caching can't be used because of the way
    # base.js explores the DOM looking for where to load deps.js.
    # @example view_test.erb
    #  <script src="<%= goog_base_js %>"></script>
    def base_js
      @sources.base_js(@env)
    end
    
    # This is where base.js looks to find deps.js by default.
    def deps_js
      @sources.deps_js(@env)
    end

    # You can serve a deps.js from anywhere you want to drop a template.
    # @example depzz.js.erb
    #  <% @response = goog.deps_response %>
    # @return (Rack::Response)
    def deps_response
      @sources.deps_response(@env, File.dirname(Rack::Utils.unescape(@env["PATH_INFO"])))
    end
    
  end
  
end
