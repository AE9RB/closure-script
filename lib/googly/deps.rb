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

  class Deps
    
    BASE_REGEX_STRING = '^\s*goog\.%s\s*\(\s*[\'"]([^\)]+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(BASE_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(BASE_REGEX_STRING % 'require')

    # @param (#each) sources Pairs of path_info and directory_name.
    # @param (Float) dwell Throttles how often a full refresh is allowed
    #  to run.  Also sent to browser in cache-control.  Although the scan
    #  is very fast and we lazy load and cache as much as we can, refresh
    #  may still be too slow to be running multiple times per second.
    def initialize(sources, dwell = 1)
      @sources = sources
      @dwell = dwell
      @semaphore = Mutex.new
      @deps = {}
    end
    attr_accessor :dwell
    
    # This cascading rack server will render deps.js in place
    # of the static file distributed with the Google Closure library.
    # @return (Array)[status, headers, body]
    def call(env, path_info=nil)
      path_info ||= Rack::Utils.unescape(env["PATH_INFO"])
      @semaphore.synchronize do
        # The last known location of deps_js has to be good enough since it
        # needs to be known for every request and needs a refresh to be known.
        refresh(env) if never_been_run
        return Googly.not_found unless @goog and @goog[:deps_js] == path_info
        # @deps_body is cleared on any mtime change
        refresh(env)
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
        # We allow caching for frames and iframes all needing a deps.js
        [200, {'Content-Type' => 'text/javascript',
           'Content-Length' => @deps_content_length,
           'Cache-Control' => "max-age=#{@dwell}, private"},
          @deps_body]
      end
    end
    

    # Obtain the path_info for where base_js is located.
    # @return [String]
    def base_js(env={})
      @semaphore.synchronize do
        refresh(env) if never_been_run
        raise ClosureBaseNotFoundError unless @goog
        @goog[:base_js]
      end
    end


    # Calculate all required files for an array of namespaces.
    # @param (Array<String>) namespaces 
    # @return (Array<String>) New Array of filenames.
    def files(namespaces, env={}, filenames=nil)
      return [] if namespaces.empty?
      ns = nil
      @semaphore.synchronize do
        refresh(env)
        # Pivot the deps to a namespace hash
        # @namespace is cleared when any requires or provides changes
        unless @ns
          @ns = {}
          @deps.each do |filename, dep|
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
      namespaces.inject(filenames) do |filenames, namespace|
        map_filenames(ns, namespace, filenames)
      end
    end
    

    protected
    
    # For some things, like checking @goog, we don't need a
    # refresh unless one has never been run.
    def never_been_run
      !@last_been_run
    end

    # Namespace recursion with circular stop on the filename
    def map_filenames(ns, namespace, filenames = [], prev = nil)
      unless source = ns[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      return if source == prev or filenames.include? source[:filename]
      source[:require].each do |required|
        map_filenames ns, required, filenames, source
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
      @deps.each {|f, dep| dep[:not_found] = true}
      # Scan filesystem for changes.
      @sources.each do |path, dir|
        dir_range = (dir.length..-1)
        Dir.glob(File.join(dir,'**','*.js')).each do |filename|
          dep = (@deps[filename] ||= {})
          dep.delete(:not_found)
          mtime = File.mtime(filename)
          if previous_goog_base_filename == filename
            @goog = previous_goog if dep[:mtime] == mtime
            previous_goog = nil
            previous_goog_base_filename = nil
          end
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
            # Record @goog as we pass by
            if dep[:provide].empty? and dep[:require].empty?
              if File.basename(filename) == 'base.js'
                if file =~ /^var goog = goog \|\| \{\};/
                  if @goog or previous_goog
                    @goog = nil
                    @deps = {} 
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
      @deps.select{|f, dep| dep[:not_found]}.each do |filename, o|
        deleted_files << filename
        @deps.delete(filename)
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