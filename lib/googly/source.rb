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

  class Source
    
    BASE_REGEX_STRING = '^\s*goog\.%s\s*\(\s*[\'"]([^\)]+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(BASE_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(BASE_REGEX_STRING % 'require')
    
    def initialize(routes)
      @routes = routes
      @deps = {}
    end
    
    # @return (Array)[status, headers, body]
    def deps_js
      refresh
      unless @deps_js
        @deps_js = []
        @deps_js << "// This deps.js was brought to you by Googlyscript\n"
        @deps_js << "goog.basePath = '';\n"
        @deps.sort{|a,b|a[1][:path]<=>b[1][:path]}.each do |filename, dep|
          @deps_js << "goog.addDependency(#{dep[:path].inspect}, #{dep[:provide].inspect}, #{dep[:require].inspect});\n"
        end
        @deps_js_content_length = @deps_js.inject(0){|sum, s| sum + s.length }.to_s
      end
      [200, {"Content-Type" => "text/javascript",
         "Content-Length" => @deps_js_content_length},
        @deps_js]
    end
    

    # Calculate all required files for an array of namespaces.
    # @param (Array<String>) namespaces 
    # @return (Array<String>) New Array of filenames.
    def files(namespaces)
      # Work up a cached hash keyed by provide namespace.
      # Everything we need is in @deps.
      refresh
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
      # Create an array of all filenames
      filenames = []
      namespaces.each do |namespace|
        map_filenames(namespace, filenames)
      end
      return filenames if filenames.length == 0
      filenames.unshift base_js
    end


    protected
    
    
    # Builds @deps (Hash{filename=>Hash}) -- The current dependencies keyed by http path.
    # Also, resets instance variables used for caching when anything changes
    # - (Array) <b>:provide</b> -- Array of <tt>goog.provide</tt> namespace strings from the file.
    # - (Array) <b>:require</b> -- Array of <tt>goog.require</tt> namespace strings from the file.
    # - (String) <b>:path</b> -- Path where Googlyscript is serving the file.  (will match env['PATH_INFO'])
    # - (Time) <b>:mtime</b> -- File.mtime
    def refresh
      added_files = []
      changed_files = []
      deleted_files = []
      # Mark everything for deletion.
      @deps.each {|f, dep| dep[:not_found] = true}
      # Scan filesystem for changes.
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
              # We're changed only if the provides or requires changes.
              # Other edits to the files don't actually alter the dependencies.
              changed_files << filename
            end
            dep[:mtime] = mtime
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
        @sources = nil
        @deps_js = nil
        puts "Googlyscript js cache: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted."
      end
    end
    

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


    # Namespace require recursion with circular dependency stop on the filename
    def map_filenames(namespace, filenames = [], prev = nil)
      unless source = @sources[namespace]
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