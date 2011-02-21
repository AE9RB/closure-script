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


class Closure
  
  # @private nodoc
  class ScriptNotFoundError < StandardError
  end

  # @private nodoc
  class ScriptCallStackTooDeepError < StandardError
  end
  
  # A Closure::Script instance is the context in which scripts are rendered.
  # It inherits everything from Rack::Request and supplies a Response instance
  # you can use for redirects, cookies, and other controller actions.
  class Script < Rack::Request
    
    ENV_ERROR_CONTENT_TYPE = 'closure.error.content_type'
    
    def initialize(env, sources, filename)
      super(env)
      @closure_private_render_stack = []
      @goog = Goog.new(env, sources, @closure_private_render_stack)
      @response = original_response = Rack::Response.new
      rendering = render(filename)
      if @response == original_response and @response.empty?
        @response.write rendering
      end
    rescue ScriptCallStackTooDeepError, ScriptNotFoundError => e
      if @closure_private_render_stack.size > 0
        # Make errors appear from the render instead of the engine.call
        e.set_backtrace e.backtrace[1..-1]
        env[ENV_ERROR_CONTENT_TYPE] = @response.finish[1]["Content-Type"] rescue nil
        raise e 
      end
      @response.status = 404
      @response.write "404 Not Found\n"
      @response.header["X-Cascade"] = "pass"
      @response.header["Content-Type"] = "text/plain"
    rescue StandardError, LoadError, SyntaxError => e
      env[ENV_ERROR_CONTENT_TYPE] = @response.finish[1]["Content-Type"] rescue nil
      raise e
    end
    
    # After rendering, #finish will be sent to the client.
    # If you replace the response or add to the response#body, 
    # the script engine rendering will not be added.
    # @return [Rack::Response]
    attr_accessor :response

    # All the cool stuff lives here.
    # @return [Goog]
    attr_accessor :goog

    # Render another script.  The same Closure::Script instance is
    # used for all internally rendered scripts so you can pass
    # information with instance variables.
    # @example view_test.erb
    #   <%= render 'util/logger_popup' %>
    # @param (String) filename Relative to current script.
    def render(filename)
      if @closure_private_render_stack.size > 100
        # Since nobody sane would recurse through here, this mainly
        # finds a render self that you might get after a copy and paste
        raise ScriptCallStackTooDeepError 
      elsif @closure_private_render_stack.size > 0
        # Hooray for relative paths and easily movable files
        filename = File.expand_path(filename, File.dirname(@closure_private_render_stack.last))
      else
        # Underbar scripts are partials by convention; keep them from rendering at root
        filename = File.expand_path(filename)
        raise ScriptNotFoundError if File.basename(filename) =~ /^_/
      end
      ext = File.extname(filename)
      files1 = [filename]
      files1 << filename + '.html' if ext == ''
      files1 << filename.sub(/.html$/,'') if ext == '.html'
      files1.each do |filename1|
        Closure.config.engines.each do |ext, engine|
          files2 = [filename1+ext]
          files2 << filename1.gsub(/.html$/, ext) if File.extname(filename1) == '.html'
          unless filename1 =~ /^_/ or @closure_private_render_stack.empty?
            files2 = files2 + files2.collect {|f| "#{File.dirname(f)}/_#{File.basename(f)}"} 
          end
          files2.each do |filename2|
            if File.file?(filename2) and File.readable?(filename2)
              if @closure_private_render_stack.empty?
                response.header["Content-Type"] = Rack::Mime.mime_type(File.extname(filename1), 'text/html')
              end
              @goog.add_dependency filename2
              @closure_private_render_stack.push filename2
              result = engine.call self, filename2
              @closure_private_render_stack.pop
              return result
            end
          end
        end
      end
      raise ScriptNotFoundError
    end
    
    # Helper for relative filenames.
    # @param [String]
    # @return [String]
    def expand_path(s)
      File.expand_path(s, File.dirname(@closure_private_render_stack.last))
    end

    # Helper to add file mtime as query for future-expiry caching.
    # @param [String]
    # @return [String]
    def expand_src(s)
      @goog.path_for(expand_path(s)) rescue s
    end
    
  end
  
end
