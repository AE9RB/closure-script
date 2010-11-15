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
  
  # This class is responsible for scanning source files and calculating dependencies.
  # Will scan every .js file in every source route for changes.

  class Deps
    
    include Responses
    
    BASE_REGEX_STRING = '^\s*goog\.%s\s*\(\s*[\'"]([^\)]+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(BASE_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(BASE_REGEX_STRING % 'require')
    
    def initialize(sources)
      @sources = sources
      @semaphore = Mutex.new
      @deps = {}
    end
    
    # @return (Array)[status, headers, body]
    def call(env, path_info=nil)
      path_info ||= Rack::Utils.unescape(env["PATH_INFO"])
      # We don't refresh here unless we're absolutely never been run yet
      refresh(env) unless @deps_body
      return not_found unless @base_js and @base_js[:deps_js] == path_info
      # Since we're now serving up deps.js, do a proper refresh always
      refresh(env)
      [200, {"Content-Type" => "text/javascript",
         "Content-Length" => @deps_content_length,
         "Cache-Control" => 'max-age=0, no-cache, must-revalidate'},
        @deps_body]
    end
    

    # Calculate all required files for an array of namespaces.
    # @param (Array<String>) namespaces 
    # @return (Array<String>) New Array of filenames.
    def files(namespaces, env=nil)
      refresh(env) if env or !@namespaces
      # Create an array of all filenames
      filenames = namespaces.inject([@base_js[:filename]]) do |filenames, namespace|
        map_filenames(namespace, filenames)
      end
      return [] if filenames.length == 1
      filenames
    end


    protected
    
    
    # Builds @deps (Hash{filename=>Hash}) -- The current dependencies keyed by http path.
    # Also, resets instance variables used for caching when anything changes
    # - (Array) <b>:provide</b> -- Array of <tt>goog.provide</tt> namespace strings from the file.
    # - (Array) <b>:require</b> -- Array of <tt>goog.require</tt> namespace strings from the file.
    # - (String) <b>:path</b> -- Path where Googlyscript is serving the file.  (will match env['PATH_INFO'])
    # - (Time) <b>:mtime</b> -- File.mtime
    def refresh(env=nil)
      # We may modify env so that refresh is never run more than once per request
      if env
        env_key = 'googly.deps_refreshed'
        return if env[env_key]
        env[env_key] = true
      end
      # Don't try to think about multi-threaded without this mutex
      @semaphore.synchronize do
        # verbose loggers
        added_files = []
        changed_files = []
        deleted_files = []
        
        # Prepare to find a moving base_js
        previous_base_js = @base_js
        @base_js = nil
        
        # Mark everything for deletion.
        @deps.each {|f, dep| dep[:not_found] = true}
        
        # Scan filesystem for changes.
        @sources.each do |path, options|
          dir = options[:dir]
          dir_range = (dir.length..-1)
          Dir.glob(File.join(dir,'**','*.js')).each do |filename|
            dep = (@deps[filename] ||= {})
            dep.delete(:not_found)
            mtime = File.mtime(filename)
            if dep[:mtime] != mtime
              @deps_body = nil
              file = File.read filename
              old_dep_provide = dep[:provide]
              dep[:provide] = file.scan(PROVIDE_REGEX).flatten.uniq
              old_dep_require = dep[:require]
              dep[:require] = file.scan(REQUIRE_REGEX).flatten.uniq
              if !dep[:path]
                raise unless filename.index(dir) == 0 # glob sanity
                dep[:path] = "#{path}#{filename.slice(dir_range)}"
                added_files << filename
              elsif old_dep_provide != dep[:provide] or old_dep_require != dep[:require]
                # We're changed only if the provides or requires changes.
                # Other edits to the files don't actually alter the dependencies.
                changed_files << filename
              end
              dep[:mtime] = mtime
              # Record base_js as we pass by
              if dep[:provide].length + dep[:require].length == 0
                if File.basename(filename) == 'base.js'
                  if file =~ /^var goog = goog \|\| \{\};/
                    if @base_js
                      raise "Google Closure base.js found more than once."
                    end
                    @base_js = {:filename => filename, :deps_js => dep[:path].gsub(/base.js$/, 'deps.js')}
                  end
                end
              end
            end
          end
        end

        # Sweep to delete not-found files.
        @deps.select{|f, dep| dep[:not_found]}.each do |filename, o|
          deleted_files << filename
          @deps.delete(filename)
        end

        # Restore base_js in the case where it hasn't changed
        if !@base_js and previous_base_js and @deps.has_key?(previous_base_js[:filename])
          @base_js = previous_base_js
        end
      
        # Decide if deps has changed.
        if 0 < added_files.length + changed_files.length + deleted_files.length
          @namespaces = nil
          STDERR.write "Googlyscript deps cache: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted.\n"
        end
      
        # Pivot the deps to a namespace hash
        unless @namespaces
          @namespaces = {}
          @deps.each do |filename, dep|
            dep[:provide].each do |provide|
              if @namespaces[provide]
                raise "Namespace #{provide.dump} provided more than once."
              end
              @namespaces[provide] = {
                :filename => filename,
                :require => dep[:require]
              }
            end
          end
        end
        
        # For serving deps.js
        unless @deps_body
          @deps_body = []
          @deps_body << "// This deps.js was brought to you by Googlyscript\n"
          @deps_body << "goog.basePath = '';\n"
          @deps.sort{|a,b|a[1][:path]<=>b[1][:path]}.each do |filename, dep|
            path = "#{dep[:path]}?#{dep[:mtime].to_i}"
            @deps_body << "goog.addDependency(#{path.inspect}, #{dep[:provide].inspect}, #{dep[:require].inspect});\n"
          end
          @deps_content_length = @deps_body.inject(0){|sum, s| sum + s.length }.to_s
        end
        
      end
      
    end
    

    # Namespace recursion with circular stop on the filename
    def map_filenames(namespace, filenames = [], prev = nil)
      unless source = @namespaces[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      return if source == prev or filenames.include? source[:filename]
      source[:require].each do |required|
        map_filenames required, filenames, source
      end
      filenames.push source[:filename]
    end
    

  end
  
end