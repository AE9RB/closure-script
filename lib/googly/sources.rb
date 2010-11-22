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
  
  # @private
  class MultipleClosureBaseError < StandardError
  end

  # @private
  class ClosureBaseNotFoundError < StandardError
  end
  
  # This class is responsible for scanning source files and managing dependencies.
  # Lasciate ogne speranza, voi ch'intrate.

  class Sources
    
    # Using regular expressions may seem clunky, but the Python scripts
    # did it this way and I've not see it fail in practice.
    GOOG_REGEX_STRING = '^\s*goog\.%s\s*\(\s*[\'"]([^\)]+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(GOOG_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(GOOG_REGEX_STRING % 'require')

    # Google Closure Library base.js is the file with no provides,
    # no requires, and defines goog a particular way.
    BASE_JS_REGEX = /^var goog = goog \|\| \{\};/
    
    # @param (Float) dwell in seconds.  
    def initialize(dwell = 1.0)
      @dwell = dwell
      @sources = []
      @semaphore = Mutex.new
      @files = {}
      @goog = nil
      @last_been_run = nil
      @deps = {}
    end


    # @return (Float) 
    # Limits how often a full refresh is allowed to run.  Blocked
    # threads can trigger unneeded refreshes in rare scenarios.
    # Also sent to browser in cache-control for frames performance.
    # Caching, lazy loading, and flagging (of env) make up the remaining
    # techniques for good performance.
    attr_accessor :dwell
    

    # Adds a new directory of source files.
    # @param (String) path Where to mount on the http server.
    # @param (String) directory Filesystem location of your sources.
    # @return (Sources) 
    def add(path, directory)
      raise "path must start with /" unless path =~ %r{^/}
      path = '' if path == '/'
      raise "path must not end with /" if path =~ %r{/$}
      raise "path already exists" if @sources.find{|s|s[0]==path}
      raise "directory already exists" if @sources.find{|s|s[1]==directory}
      @sources << [path, File.expand_path(directory)]
      @sources.sort! {|a,b| b[0] <=> a[0]}
      self
    end
    

    # Yields path and directory for each of the added sources.
    # @yield (path, directory) 
    # @return (Sources) 
    def each
      @sources.each { |path, directory| yield path, directory }
      self
    end
    
    
    # Determine the path_info for where base_js is located.
    # @return [String]
    def base_js(env)
      @semaphore.synchronize do
        refresh(env) unless @last_been_run
        raise ClosureBaseNotFoundError unless @goog
        @goog[:base_js]
      end
    end
    

    # Determine the path_info for where deps_js is located.
    # @return [String]
    def deps_js(env)
      @semaphore.synchronize do
        refresh(env) unless @last_been_run
        raise ClosureBaseNotFoundError unless @goog
        @goog[:deps_js]
      end
    end
    

    # Builds a Rack::Response to serve a dynamic deps.js
    # @return (Rack::Response) 
    def deps_response(env, base=nil)
      @semaphore.synchronize do
        refresh(env)
        unless base
          raise ClosureBaseNotFoundError unless @goog
          base = File.dirname(@goog[:base_js])
        end
        base = Pathname.new(base)
        unless @deps[base]
          response = @deps[base] ||= Rack::Response.new
          response.write "// Deps by Googlyscript\n"
          @files.sort{|a,b|a[1][:path]<=>b[1][:path]}.each do |filename, dep|
            path = Pathname.new(dep[:path]).relative_path_from(base)
            path = "#{path}?#{dep[:mtime].to_i}"
            response.write "goog.addDependency(#{path.dump}, #{dep[:provide].inspect}, #{dep[:require].inspect});\n"
          end
          response.headers['Content-Type'] = 'application/javascript'
          response.headers['Cache-Control'] = "max-age=#{[1,@dwell.floor].max}, private"
          response.headers['Last-Modified'] = Time.now.httpdate
        end
        mod_since = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE']) rescue nil
        if mod_since == Time.httpdate(@deps[base].headers['Last-Modified'])
          Rack::Response.new [], 304 # Not Modified
        else
          @deps[base]
        end
      end
    end
    

    # Calculate all required files for a namespace.
    # @param (String) namespace
    # @return (Array<String>) New Array of filenames.
    def files_for(env, namespace, filenames=nil)
      ns = nil
      @semaphore.synchronize do
        refresh(env)
        # Pivot the deps to a namespace hash
        # @ns is cleared when any requires or provides changes
        unless @ns
          @ns = {}
          @files.each do |filename, dep|
            dep[:provide].each do |provide|
              if @ns[provide]
                raise "Namespace #{provide.dump} provided more than once."
              end
              @ns[provide] = {
                :filename => filename,
                :require => dep[:require]
              }
            end
          end
        end
        ns = @ns
        if !filenames or filenames.empty?
          raise ClosureBaseNotFoundError unless @goog
          filenames ||= []
          filenames << @goog[:base_filename]
        end
      end
      # Since @ns is only unset, not modified, by another thread, we
      # can work with a local reference.  This has been finely tuned and
      # runs fast, but it's still nice to release any other threads early.
      calcdeps(ns, namespace, filenames)
    end
    

    protected
    
    # Namespace recursion with circular stop on the filename
    def calcdeps(ns, namespace, filenames, prev = nil)
      unless source = ns[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      return if source == prev or filenames.include? source[:filename]
      source[:require].each do |required|
        calcdeps ns, required, filenames, source
      end
      filenames.push source[:filename]
    end
    
    
    def refresh(env)
      # Use env so that refresh is never run more than once per request
      env_key = 'googly.deps_refreshed'
      return if env[env_key]
      env[env_key] = true
      # Having been run within the dwell period is good enough
      return if @last_been_run and Time.now - @last_been_run < @dwell
      # verbose loggers
      added_files = []
      changed_files = []
      deleted_files = []
      # Prepare to find a moving base_js
      previous_goog_base_filename = @goog ? @goog[:base_filename] : nil
      previous_goog = @goog
      @goog = nil
      # Mark everything for deletion.
      @files.each {|f, dep| dep[:not_found] = true}
      # Scan filesystem for changes.
      @sources.each do |path, dir|
        dir_range = (dir.length..-1)
        Dir.glob(File.join(dir,'**','*.js')).each do |filename|
          dep = (@files[filename] ||= {})
          dep.delete(:not_found)
          mtime = File.mtime(filename)
          if previous_goog_base_filename == filename
            @goog = previous_goog if dep[:mtime] == mtime
            previous_goog = nil
            previous_goog_base_filename = nil
          end
          if dep[:mtime] != mtime
            @deps = {}
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
            # Record @goog as we pass by
            if dep[:provide].empty? and dep[:require].empty?
              if File.basename(filename) == 'base.js'
                if file =~ BASE_JS_REGEX
                  if @goog or previous_goog
                    @goog = nil
                    @files = {} 
                    raise MultipleClosureBaseError
                  end
                  @goog = {:base_filename => filename,
                           :base_js => dep[:path],
                           :deps_js => dep[:path].gsub(/base.js$/, 'deps.js')}
                end
              end
            end
          end
        end
      end
      # Sweep to delete not-found files.
      @files.select{|f, dep| dep[:not_found]}.each do |filename, o|
        deleted_files << filename
        @files.delete(filename)
      end
      # Decide if deps has changed.
      if 0 < added_files.length + changed_files.length + deleted_files.length
        @ns = nil
        STDERR.write "Googlyscript deps cache: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted.\n"
      end
      # Finish
      @last_been_run = Time.now
    end
    

  end
  
end