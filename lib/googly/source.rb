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

  class Source
    
    attr_reader :deps
    
    BASE_REGEX_STRING = '^\s*goog\.%s\(\s*[\'"](.+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(BASE_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(BASE_REGEX_STRING % 'require')
    
    def initialize(routes)
      @routes = routes
      @deps = {}
    end
    
    # The object starts out with knowledge of no deps.
    # This will scan and cache every .js file in every route.
    # If @deps are altered (except mtime), returns true.
    def deps_changed?
      added_files = []
      changed_files = []
      deleted_files = []
      # Mark everything for deletion
      @deps.each {|f, dep| dep[:not_found] = true}
      # Scan for changes
      @routes.each do |path, options|
        next unless options[:deps]
        dir = options[:dir]
        dir_range = (dir.length..-1)
        Dir.glob(File.join(dir,'**','**.js')).each do |filename|
          dep = (@deps[filename] ||= {})
          dep.delete(:not_found)
          mtime = File.mtime(filename)
          if dep[:mtime] != mtime
            file = File.read filename
            old_dep_provide = dep[:provide]
            dep[:provide] = file.scan(PROVIDE_REGEX).flatten
            old_dep_require = dep[:require]
            dep[:require] = file.scan(REQUIRE_REGEX).flatten
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
      # Delete not-found files
      @deps.select{|f, dep| dep[:not_found]}.each do |filename, o|
        deleted_files << filename
        @deps.delete(filename)
      end
      # return true if anything changed
      if 0 < added_files.length + changed_files.length + deleted_files.length
        puts "Googlyscript js cache: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted."
        return true
      else
        puts "Googlyscript js cache: deps not changed."
        return false
      end
    end
    
  end
  
end