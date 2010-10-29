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

  class Source
    
    BASE_REGEX_STRING = '^\s*goog\.%s\s*\(\s*[\'"]([^\)]+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(BASE_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(BASE_REGEX_STRING % 'require')
    
    def initialize(routes)
      @routes = routes
      @deps = {}
    end
    
    # Scan every .js file in every route for changes since last scan.
    # Updates {Source#deps} as needed.
    # @return (Boolean) True if any changes to {Source#deps} (except :mtime).
    def deps_changed?
      added_files = []
      changed_files = []
      deleted_files = []
      # Mark everything for deletion
      @deps.each {|f, dep| dep[:not_found] = true}
      # Scan for changes
      @routes.each do |path, options|
        next unless options[:source]
        dir = options[:dir]
        dir_range = (dir.length..-1)
        Dir.glob(File.join(dir,'**','*.js')).each do |filename|
          dep = (@deps[filename] ||= {})
          dep.delete(:not_found)
          mtime = File.mtime(filename)
          if dep[:mtime] != mtime
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
              changed_files << filename
            end
            dep[:mtime] = mtime
          end
        end
      end
      # Sweep to delete not-found files
      @deps.select{|f, dep| dep[:not_found]}.each do |filename, o|
        deleted_files << filename
        @deps.delete(filename)
      end
      # Decide if anything changed
      if 0 < added_files.length + changed_files.length + deleted_files.length
        @sources = nil
        puts "Googlyscript js cache: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted."
        return true
      else
        puts "Googlyscript js cache: deps not changed."
        return false
      end
    end
    

    # The current dependencies.  Read this after calling {Source#deps_changed?}  Do not change.
    # The values for the returned Hash contain a Hash describing a file.
    # - (Array) <b>:provide</b> -- Array of <tt>goog.provide</tt> namespace strings from the file.
    # - (Array) <b>:require</b> -- Array of <tt>goog.require</tt> namespace strings from the file.
    # - (String) <b>:path</b> -- Path where Googlyscript is serving the file.  (will match env['PATH_INFO'])
    # - (Time) <b>:mtime</b> -- File.mtime
    # @return (Hash{filename=>Hash})
    attr_reader :deps
    

    # Calculate all required files for an array of namespaces.
    # This will also refresh {Source#deps}.
    # @param (Array<String>) namespaces 
    # @return (Array<String>) Full filesystem path and name for each file.
    def files(namespaces)
      # Work up a cached hash keyed by provide namespace.
      # Everything we need is in @deps.
      deps_changed?
      unless @sources
        @sources = {}
        @deps.each do |filename, dep|
          dep[:provide].each do |provide|
            if @sources[provide]
              raise "Namespace #{provide.dump} provided more than once."
            end
            @sources[provide] = {
              :filename => filename,
              :require => dep[:require]
            }
          end
        end
      end
      # Create an array of filenames
      files = []
      namespaces.each do |namespace|
        dependencies(namespace).each do |source_info|
          unless files.include? source_info[:filename]
            files.push source_info[:filename] 
          end
        end
      end
      return files if files.length == 0
      files.unshift base_js
      files
    end


    protected
    

    # Looks for a single file named base.js without
    # any requires or provides that defines var goog inside.
    # This is how the original python scripts did it
    # except I added the provide+require check.
    def base_js
      found_base_js = nil
      @deps.each do |filename, dep|
        if File.basename(filename) == 'base.js'
          if dep[:provide].length + dep[:require].length == 0
            if File.read(filename) =~ /^var goog = goog \|\| \{\};/
              if found_base_js
                raise "Google Closure base.js found more than once."
              end
              found_base_js = filename
            end
          end
        end
      end
      raise "Google Closure base.js could not be found." unless found_base_js
      found_base_js
    end
    

    # Recursion with circular dependency stop
    def dependencies(namespace, deps_list = [], traversal_path = [])
      unless source = @sources[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      return deps_list if traversal_path.include? namespace
      traversal_path.push namespace
      source[:require].each do |required|
        dependencies required, deps_list, traversal_path
      end
      traversal_path.pop
      deps_list.push source
      return deps_list
    end

    
  end
  
end