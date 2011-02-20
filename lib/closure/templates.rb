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

require 'thread'

class Closure
  
  # The arguments to this middleware are the arguments you would use for
  # SoyToJsSrcCompiler.jar (get them using: `java -jar SoyToJsSrcCompiler.jar`).
  # Closure Script will expand filenames that appear to be globs,
  # as shown in the examples.  You may still use static filenames.
  # File modification times are remembered and compilation is run only
  # when source changes are detected.
  # @example config.ru
  #  require 'closure'
  #  Closure.add_source :soy, '/soy'
  #  Closure.add_source 'app/javascripts', '/app'
  #  Closure.add_source 'vendor/javascripts', '/vendor'
  #  use Closure::Templates, %w{
  #    --shouldProvideRequireSoyNamespaces
  #    --cssHandlingScheme goog
  #    --shouldGenerateJsdoc
  #    --outputPathFormat {INPUT_DIRECTORY}{INPUT_FILE_NAME_NO_EXT}.js
  #    app/javascripts/**/*.soy
  #    vendor/javascripts/**/*.soy
  #  }
  
  class Templates
    
    # Logs in env[ENV_ERRORS] will persist until the errors are fixed.
    # It will be nil when no errors or a string with the Java exception.
    # It will be an array if you have multiple Soy middlewares running.
    # By default, these errors are available on the Javascript console
    # after loading goog.deps_js or a Compiler#to_response_with_console.
    ENV_ERRORS = 'closure.template.errors'
    
    # Creates javascript for errors in a Rack environment.
    # @private - internal use only
    # @param (Hash) env Rack environment.
    def self.errors_js(env)
      errors = [env[ENV_ERRORS]].flatten.compact
      return nil if errors.empty?
      out = 'try{console.error('
      out += "'Closure Templates: #{errors.size} error(s)', "
      out += '"\n\n", '
      out += errors.join("\n").dump
      out += ')}catch(err){}'
      out
    end
    
    # @param app [#call] The Rack application
    # @param args [Array] Arguments for SoyToJsSrcCompiler.jar.  Supports globbing.
    # @param dwell [Float] in seconds.  
    def initialize(app, args, dwell = 1.0)
      @app = app
      @args = args
      @dwell = dwell
      @check_after = Time.now.to_f
      @mtimes = {}
      @semaphore = Mutex.new
      @errors = nil
    end
    
    # @return (Float) 
    attr_accessor :dwell

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      # This lock will block all other threads until soy is compiled
      # (it is not to synchronize globals like in Closure::Sources)
      @semaphore.synchronize do
        if Time.now.to_f > @check_after
          args = @args.collect {|a| a.to_s } # for bools and numerics
          files = []
          # expand filename globs
          mode = :start
          args_index = 0
          while args_index < args.length
            if mode == :start
              if args[args_index] == '--outputPathFormat'
                mode = :expand
                args_index += 1
              end
              args_index += 1
            else 
              arg = args[args_index]
              if arg =~ /\*/
                args[args_index,1] = Dir.glob arg
              else
                args_index += 1
              end
            end
          end
          # extract filenames
          mode = :start
          args.each do |arg|
            mode = :out and next if arg == '--outputPathFormat'
            files << arg if mode == :collect
            mode = :collect if mode == :out
          end
          # detect source changes
          compiled = true
          files.each do |file|
            filename = File.expand_path file
            mtime = File.mtime filename rescue Errno::ENOENT
            last_mtime = @mtimes[filename]
            if !mtime or !last_mtime or last_mtime != mtime
              @mtimes[filename] = mtime
              compiled = false
              break
            end
          end
          # compile as needed
          if !compiled or @errors
            out, err = Closure.run_java Closure.config.soy_js_jar, 'com.google.template.soy.SoyToJsSrcCompiler', args
            if err.empty?
              @errors = nil
            else
              @errors = err
            end
          end
          @check_after = Time.now.to_f + @dwell
        end
      end
      # Make always available the errors from every Soy in the stack
      if env[ENV_ERRORS].kind_of?(Array)
        env[ENV_ERRORS] << @errors
      else
        if env.has_key? ENV_ERRORS
          env[ENV_ERRORS] = [env[ENV_ERRORS], @errors]
        else
          env[ENV_ERRORS] = @errors
        end
      end
      # Onward
      @app.call(env)
    end
    
  end
  
end
