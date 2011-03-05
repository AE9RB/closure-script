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
  
  # Scripts render with an instance named goog in the context.
  
  class Goog

    def initialize(env, sources, render_stack)
      @sources = sources
      @env = env
      @render_stack = render_stack
      @dependencies = []
    end
    
    # You can add additional files to have their mtimes scanned.
    # Perhaps you want to use a .yml file to define build options.
    # Closure::Script calls this for every render so you don't need
    # to define compiler arguments in the same script that calls compile.
    def add_dependency(dependency)
      dependency = File.expand_path dependency, File.dirname(@render_stack.last)
      @dependencies << dependency unless @dependencies.include? dependency
    end
    
    # If you change any javascript sources then you need to tell Script.
    # This is a lazy refresh, you may call it repeatedly.
    def refresh
      @sources.invalidate @env
    end
    
    # Convert soy templates to javascript.  Accepts all arguments that
    # SoyToJsSrcCompiler.jar support plus it expands filename globs.
    # All source filenames are relative to the script calling #soy_to_js.
    # @param [Array<String>] args
    def soy_to_js(args)
      Templates::compile(args, File.dirname(@render_stack.last))
      refresh
    end

    # Compile javascript.  Accepts every argument that compiler.jar supports.
    # Accepts new `--ns namespace` option which literally expands into
    # `--js filename` arguments in place to satisfy the namespace.
    # If you specify a --js_output_file then the compiler will check File.mtime
    # on every source file plus all the rendered Scripts and skip the compilation
    # if the js_output_file is newest.
    # Paths are relative to the script calling #compile.
    # @example myapp.js.erb
    #   <% @response = goog.compile(%w{
    #     --js_output_file ../public/myapp.js
    #     --ns myapp.HelloWorld
    #     --compilation_level ADVANCED_OPTIMIZATIONS
    #   }).to_response %>
    # @param [Array<String>] args
    # @return [Compiler]
    def compile(args)
      args = Array.new args # work on a copy
      pre_js_tempfile = nil
      begin
        orig_externs = Compiler::Util.arg_values(args, '--externs')
        Compiler::Util.namespace_augment(args, @sources, @env)
        mods = Compiler::Util.module_augment args

        if Compiler::Util.arg_values(args, '--compilation_level').empty?
          # Raw mode
          comp = Compiler::Compilation.new '', nil, nil, @env
          unless mods.empty?
            comp << Compiler::Util.module_info(mods)
            comp << Compiler::Util.module_uris_raw(mods, @sources)
          end
          js_counter = 0
          args_index = 0
          while args_index < args.length
            option, value = args[args_index, 2]
            if option == '--js'
              value = File.expand_path value, File.dirname(@render_stack.last)
              script_tag = "<script src=#{src_for(value).dump}></script>"
              comp << "document.write(#{script_tag.dump});\n"
              js_counter += 1
              # For modules, just the files for the first module
              break if !mods.empty? and js_counter >= mods[0][:files].length
            end
            args_index = args_index + 2
          end
        else
          # Compiled mode
          module_output_path_prefix = Compiler::Util.arg_values(args, '--module_output_path_prefix').last
          if !mods.empty? and !module_output_path_prefix
            # raise this before compilation so we don't write to a weird place
            raise "--module_output_path_prefix is required when using --module"
          end
          # If the externs were changed by namespace_augment then we need to include
          # a temp file containing the goog.provide statements that satisfy compiler.jar.
          if orig_externs != Compiler::Util.arg_values(args, '--externs')
            pre_js_tempfile = Tempfile.new 'closure_pre_js'
            # Insert before the first --js (in case of modules)
            args_index = 0
            while args_index < args.length
              if args[args_index] == '--js'
                args.insert args_index, '--js', pre_js_tempfile.path
                break
              end
              args_index = args_index + 2
            end
            pre_js_tempfile.open
            @sources.deps_response(File.dirname(base_js), @env).each do |s|
              next unless s =~ /^goog\.provide/
              pre_js_tempfile.write s
            end
            pre_js_tempfile.close
            # File mtime is rolled back to not trigger compilation.
            File.utime(Time.now, Time.at(0), pre_js_tempfile.path)
          end
          comp = Compiler.compile args, @dependencies, File.dirname(@render_stack.last), @env
          unless mods.empty?
            refresh
            prefix =  File.expand_path module_output_path_prefix, File.dirname(@render_stack.last)
            if comp.js_output_file
              File.open comp.js_output_file, 'w' do |f|
                f.write Compiler::Util.module_info mods
                f.write Compiler::Util.module_uris_compiled mods, @sources, prefix
              end
            else
              comp << Compiler::Util.module_info(mods)
              comp << Compiler::Util.module_uris_compiled(mods, @sources, prefix)
            end
            # Load the first module
            first_module_file = module_output_path_prefix + mods[0][:name] + '.js'
            first_module_file = File.expand_path first_module_file, File.dirname(@render_stack.last)
            script_tag = "<script src=#{src_for(first_module_file).dump}></script>"
            comp << "document.write(#{script_tag.dump});\n"
          end
        end
        comp
      ensure
        if pre_js_tempfile
          pre_js_tempfile.close
          pre_js_tempfile.unlink 
        end
      end
    end
    
    # Calculate the deps src for a filename.
    # @param (String) filename
    # @return (String) http path info with forward caching query.
    def src_for(filename)
      filename = File.expand_path filename
      @sources.src_for(filename, @env)
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
      @sources.files_for(namespace, filenames, @env)
    end

    # The Google Closure base.js script.
    # If you use this instead of a static link, you are free to relocate relative
    # to the Google Closure library without updating every html fixture page.
    # @example view_test.erb
    #  <script src="<%= goog.base_js %>"></script>
    # @return [String]
    def base_js
      @sources.base_js(@env)
    end
    
    # This is where base.js looks to find deps.js by default.  You will always
    # be served a Closure Script generated deps.js from this location.
    # Very old Library versions may get confused by the forward caching query
    # string; either update your base.js, install a deps_response Script where
    # it's looking, or manually set CLOSURE_BASE_PATH.
    # @return [String]
    def deps_js
      @sources.deps_js(@env)
    end

    # You can serve a deps.js from anywhere you want to drop a script.
    # @example something.js.erb
    #  <% @response = goog.deps_response %>
    # @return (Rack::Response)
    def deps_response
      @sources.deps_response(File.dirname(Rack::Utils.unescape(@env["PATH_INFO"])), @env)
    end

    # Advanced Scripts may need to know where all the sources are.
    # This has potential for a source browser, editor, and more.
    # @example
    #  goog.each {|directory, path| ... }
    def each
      @sources.each do |directory, path| 
        yield directory, path
      end
    end
    include Enumerable
    
  end
  
end
