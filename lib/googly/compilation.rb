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
  
  class Compilation

    # Makefile is used as root dir for compilation and checked
    # for mtime; the contents are not important.
    def initialize(args, deps, makefile=nil, env={})
      java_opts = args.collect{|a|a.to_s.dump}.join(', ')
      @stdout, @stderr = Googly.java("Googly.compile_js(new String[]{#{java_opts}});")
    end

    # Always returns the compiled javascript, or possibly an empty string.
    # For easy use in templates.
    def to_s
      if @js_output_file
        File.read(@js_output_file) rescue ''
      else
        @stdout
      end
    end
    
    # Results from compiler.jar.  If you didn't specify a --js_output_file
    # then this will be the compiled script.  Otherwise, it's usually empty.
    attr_reader :stdout
    
    # Results from compiler.jar.  The log, when there is one, is found here.
    attr_reader :stderr
    

    #TODO will summary_detail_level=3 contribute to error detection?
    
  end
  
end
