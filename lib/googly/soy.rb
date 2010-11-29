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
  
  # The arguments to this middleware are the arguments you would use for
  # SoyToJsSrcCompiler.jar (get them using: `java -jar SoyToJsSrcCompiler.jar`).
  # Googlyscript will expand pairs of filenames that appear to be globs,
  # as shown in the examples.  You may still use static filenames.
  # File modification times are remembered and compilation is run only
  # when source changes are detected.
  # @example config.ru
  #  require 'googlyscript'
  #  Googly.script '/soy', :soy_js
  #  Googly.script '/app', 'app/javascripts'
  #  Googly.script '/vendor', 'vendor/javascripts'
  #  use Googly::Soy, %w{
  #    --shouldProvideRequireSoyNamespaces
  #    --cssHandlingScheme goog
  #    --shouldGenerateJsdoc
  #    --outputPathFormat {INPUT_DIRECTORY}{INPUT_FILE_NAME_NO_EXT}.js
  #    app/javascripts/** *.soy
  #    vendor/javascripts/** *.soy
  #  }
  
  class Soy
    
    # @param app [#call] The Rack application
    # @param dwell [Float] in seconds.  
    def initialize(app, args, dwell = 1.0)
      @app = app
      @args = args
      @dwell = dwell
      @check_after = Time.now.to_f
      @mtimes = {}
      @semaphore = Mutex.new
    end
    
    # @return (Float) 
    attr_accessor :dwell

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      # This lock will block all other threads until soy is compiled
      # (it is not to synchronize globals like in sources)
      @semaphore.synchronize do
        if Time.now.to_f > @check_after
          args = @args.dup
          files = []
          # expand filename globs
          mode = :start
          args_index = 0
          while args_index < args.length
            arg = args[args_index]
            args_index += 1
            mode = :out and next if arg == '--outputPathFormat'
            if mode == :expand and arg =~ /\/\*\*$/
              args[args_index-1,2] = Dir.glob(File.join(arg, args[args_index]))
            end
            mode = :expand if mode == :out
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
          unless compiled
            java_opts = args.collect{|a|a.to_s.dump}.join(', ')
            puts "compiling soy: #{java_opts}"
            out, err = Googly.java("Googly.compile_soy_to_js_src(new String[]{#{java_opts}});")
            #TODO find a better way to get this to the developer
            # perhaps pass it down env and Googly::Server can persist it?
            puts err unless err.empty?
          end
          @check_after = Time.now.to_f + @dwell
        end
      end
      @app.call(env)
    end
    
  end
  
end
