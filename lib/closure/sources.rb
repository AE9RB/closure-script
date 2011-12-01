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

require 'pathname'
require 'thread'

class Closure
  
  # This class is responsible for scanning source files and managing dependencies.

  class Sources

    # @private
    class MultipleBaseJsError < StandardError
    end

    # @private
    class BaseJsNotFoundError < StandardError
    end
    
    include Enumerable
    
    # Using regular expressions may seem clunky, but the Python scripts
    # did it this way and I've not see it fail in practice.
    GOOG_REGEX_STRING = '^\s*goog\.%s\s*\(\s*[\'"]([^\)]+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(GOOG_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(GOOG_REGEX_STRING % 'require')

    # Google Closure Library base.js is the file with no provides,
    # no requires, and defines goog a particular way.
    BASE_JS_REGEX = /^var goog = goog \|\| \{\};/
    
    # Flag env so that refresh is never run more than once per request
    ENV_FLAG = 'closure.sources_fresh'
    
    # @param (Float) dwell in seconds.  
    def initialize(dwell = 1.0)
      @dwell = dwell
      @files = {}
      @sources = []
      @semaphore = Mutex.new
      @last_been_run = nil
      reset_all_computed_instance_vars
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
    # @return (Sources) self
    def add(directory, path=nil)
      raise "immutable once used" if @last_been_run
      if path
        raise "path must start with /" unless path =~ %r{^/}
        path = '' if path == '/'
        raise "path must not end with /" if path =~ %r{/$}
        raise "path already exists" if @sources.find{|s|s[0]==path}
      end
      raise "directory already exists" if @sources.find{|s|s[1]==directory}
      @sources << [File.expand_path(directory), path]
      @sources.sort! {|a,b| (b[1]||'') <=> (a[1]||'')}
      self
    end
    

    # Yields path and directory for each of the added sources.
    # @yield (path, directory) 
    def each
      @sources.each { |directory, path| yield directory, path }
    end
    
    
    # Determine the path_info and query_string for loading base_js.
    # @return [String]
    def base_js(env={})
      if (goog = @goog) and @last_been_run
        return "#{goog[:base_js]}?#{goog[:base_js_mtime].to_i}"
      end
      @semaphore.synchronize do
        refresh(env)
        raise BaseJsNotFoundError unless @goog
        @goog[:base_js]
      end
    end
    

    # Determine the path_info for where deps_js is located.
    # @return [String]
    def deps_js(env={})
      # Because Server uses this on every call, it's best to never lock.
      # We grab a local goog so we don't need the lock if everything looks good.
      # This works because #refresh creates new @goog hashes instead of modifying.
      if (goog = @goog) and @last_been_run
        return goog[:deps_js]
      end
      @semaphore.synchronize do
        refresh(env)
        raise BaseJsNotFoundError unless @goog
        @goog[:deps_js]
      end
    end
    

    # Builds a Rack::Response to serve a dynamic deps.js
    # @return (Rack::Response) 
    def deps_response(base, env={})
      @semaphore.synchronize do
        refresh(env)
        base = Pathname.new(base)
        unless @deps[base]
          response = @deps[base] ||= Rack::Response.new
          response.write "// Dynamic Deps by Closure Script\n"
          @files.sort{|a,b|(a[1][:path]||'')<=>(b[1][:path]||'')}.each do |filename, dep|
            if dep[:path]
              path = Pathname.new(dep[:path]).relative_path_from(base)
              path = "#{path}?#{dep[:mtime].to_i}"
              response.write "goog.addDependency(#{path.dump}, #{dep[:provide].inspect}, #{dep[:require].inspect});\n"
            end
          end
          response.headers['Content-Type'] = 'application/javascript'
          response.headers['Cache-Control'] = "max-age=#{[1,@dwell.floor].max}, private, must-revalidate"
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
    def files_for(namespace, filenames=nil, env={})
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
                @ns = nil
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
          raise BaseJsNotFoundError unless @goog
          filenames ||= []
          filenames << @goog[:base_filename]
        end
      end
      # Since @ns is only unset, not modified, by another thread, we
      # can work with a local reference.  This has been finely tuned and
      # runs fast, but it's still nice to release any other threads early.
      calcdeps(ns, namespace, filenames)
    end
    
    
    # Calculate the file server path for a filename
    # @param (String) filename
    # @return (String)
    def src_for(filename, env={})
      @semaphore.synchronize do
        refresh(env)
        file = @files[filename]
        unless file and file.has_key? :path
          raise "#{filename.dump} is not available from file server"
        end
        "#{file[:path]}?#{file[:mtime].to_i}"
      end
    end
   
   
    # Return all provided and required namespaces for a file.
    # @param (String) filename
    # @return (String)
    def namespaces_for(filename, env={})
      @semaphore.synchronize do
        refresh(env)
        file = @files[filename]
        raise "#{filename.dump} not found" unless file
        file[:provide] + file[:require]
      end
    end


    # Certain Script operations, such as building Templates, will need
    # to invalidate the cache.
    def invalidate(env)
      env.delete ENV_FLAG
      @last_been_run = Time.at 0
    end
    

    protected

    
    # Namespace recursion with two-way circular stop
    def calcdeps(ns, namespace, filenames, prev = [])
      unless source = ns[namespace]
        msg = "#{prev.last[:filename]}: " rescue ''
        msg += "Namespace #{namespace.dump} not found."
        raise msg
      end
      if prev.include? source
        return
      else
        prev.push source
      end
      return if filenames.include?(source[:filename])
      source[:require].each do |required|
        calcdeps ns, required, filenames, prev
      end
      filenames.push source[:filename]
    end
    
    
    # Lasciate ogne speranza, voi ch'intrate.
    def refresh(env)
      return if env[ENV_FLAG]
      env[ENV_FLAG] = true
      # Having been run within the dwell period is good enough
      return if @last_been_run and Time.now - @last_been_run < @dwell
      # verbose loggers
      added_files = []
      changed_files = []
      deleted_files = []
      # Prepare to find a moving base_js
      previous_goog_base_filename = @goog ? @goog[:base_filename] : nil
      goog = nil
      # Mark everything for deletion.
      @files.each {|f, dep| dep[:not_found] = true}
      # Scan filesystem for changes.
      @sources.each do |dir, path|
        dir_range = (dir.length..-1)
        Dir.glob(File.join(dir,'**','*.js')).each do |filename|
          dep = (@files[filename] ||= {})
          dep.delete(:not_found)
          mtime = File.mtime(filename)
          if previous_goog_base_filename == filename
            if dep[:mtime] == mtime
              multiple_base_js_failure if goog
              goog = @goog 
            end
            previous_goog_base_filename = nil
          end
          if dep[:mtime] != mtime
            @deps = {}
            file = File.read filename
            old_dep_provide = dep[:provide]
            dep[:provide] = file.scan(PROVIDE_REGEX).flatten.uniq
            old_dep_require = dep[:require]
            dep[:require] = file.scan(REQUIRE_REGEX).flatten.uniq
            if !dep.has_key? :path
              raise unless filename.index(dir) == 0 # glob sanity
              if path
                dep[:path] = "#{path}#{filename.slice(dir_range)}"
              else
                dep[:path] = nil
              end
              added_files << filename
            elsif old_dep_provide != dep[:provide] or old_dep_require != dep[:require]
              # We're changed only if the provides or requires changes.
              # Other edits to the files don't actually alter the dependencies.
              changed_files << filename
            end
            dep[:mtime] = mtime
            # Record goog as we pass by
            if dep[:provide].empty? and dep[:require].empty?
              if File.basename(filename) == 'base.js'
                if file =~ BASE_JS_REGEX
                  multiple_base_js_failure if goog
                  goog = {:base_filename => filename}
                  if dep[:path]
                    goog[:base_js] = dep[:path]
                    goog[:base_js_mtime] = mtime
                    goog[:deps_js] = dep[:path].gsub(/base.js$/, 'deps.js')
                  end
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
      end
      # Finish
      @goog = goog
      @last_been_run = Time.now
    end
    
    # We can't trust anything if we see more than one goog
    def multiple_base_js_failure
      reset_all_computed_instance_vars
      raise MultipleBaseJsError
    end
    
    def reset_all_computed_instance_vars
      @deps = {}
      @ns = nil
      @goog = nil
    end

  end
  
end