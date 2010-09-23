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

  class Compiler
    
    def initialize(source)
      source.refresh
      prepare_sources_hash(source)
      find_the_one_true_base_js(source)
    end

    def files(namespaces)
      files = [@base_js]
      [namespaces].flatten.each do |namespace|
        dependencies(namespace).each do |source_info|
          unless files.include? source_info[:filename]
            files.push source_info[:filename] 
          end
        end
      end
      files
    end

    protected
    
    # The deps from Googly::Source are optimized for scanning the filesystem
    # and serving up deps.js.  This creates a new hash optimized for making a
    # dependency graph; one keyed by the provide instead of the filename.
    def prepare_sources_hash(source)
      @sources = {}
      source.deps.each do |filename, dep|
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
    
    # Looks for a single file named base.js without
    # any requires or provides that defines var goog inside.
    # This is how the original python scripts did it
    # except I added the provide+require check.
    def find_the_one_true_base_js(source)
      source.deps.each do |filename, dep|
        if File.basename(filename) == 'base.js'
          if dep[:provide].length + dep[:require].length == 0
            p filename
            if File.read(filename) =~ /^var goog = goog \|\| \{\};/
              if @base_js
                raise "Google closure base.js found more than once"
              end
              @base_js = filename
            end
          end
        end
      end
      raise "Google closure base.js could not be found" unless @base_js
    end
    
    def dependencies(namespace, deps_list = [], traversal_path = [])
      unless source = @sources[namespace]
        raise "Namespace #{namespace.dump} not found." 
      end
      if traversal_path.include? namespace
        traversal_path.push namespace
        raise "Circular dependency error. #{traversal_path.join(', ')}\n"
      end
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