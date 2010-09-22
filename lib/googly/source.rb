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
    
    def check_deps
      added_files = []
      changed_files = []
      deleted_files = []
      # Set up deps and mark everything for deletion
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
            if dep == {}
              added_files << filename
            else
              changed_files << filename
            end
            raise unless filename.index(dir) == 0
            file = File.read filename
            dep[:path] = "#{path}#{filename.slice(dir_range)}"
            dep[:provide] = file.scan(PROVIDE_REGEX).flatten
            dep[:require] = file.scan(REQUIRE_REGEX).flatten
            dep[:mtime] = mtime
          end
        end
      end
      # Delete not-found files
      @deps.select{|f, dep| dep[:not_found]}.each do |filename, options|
        deleted_files << filename
        @deps.delete(filename)
      end
      # return true if anything changed
      if 0 < added_files.length + changed_files.length + deleted_files.length
        puts "Googlyscript sources: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted."
        return true
      else
        return false
      end
    end
    
  end
  
end