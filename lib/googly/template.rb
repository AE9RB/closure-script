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
  class TemplateNotFoundError < StandardError
  end

  # @private
  class TemplateCallStackTooDeepError < StandardError
  end
  
  # A Googly::Template instance is the context in which Ruby templates are rendered.
  # It inherits everything from Rack::Request and supplies a response instance
  # you can use for redirects, cookies, and other controller actions.
  class Template < Rack::Request
    
    # Create a new instance of {Template}.
    # Using the initializer instead of rendering as a separate step provides
    # 404 messages instead of exceptions when the file is not found.
    # Also, exceptions from internal render calls will appear thrown from the
    # render command to help speed up debugging.
    def initialize(env, filename = nil)
      super(env)
      @render_call_stack = []
      @response = original_response = Rack::Response.new
      if filename
        rendering = render(filename)
        if @response == original_response and @response.status == 200 and @response.empty?
          @response.write rendering
        end
      end
    rescue TemplateCallStackTooDeepError, TemplateNotFoundError => e
      e.set_backtrace e.backtrace[1..-1]
      raise e if @render_call_stack.size > 1
      @response.status = 404
      @response.write "404 Not Found\n"
      @response.header["X-Cascade"] = "pass"
      @response.header["Content-Type"] = "text/plain"
    end
    
    # After rendering, #finish will be sent to the client.
    # If you change anything other than the header, the template
    # rendering will not be added to this response.
    # @return [Rack::Response]
    attr :response

    # Render another template.  The same Googly::Template instance is
    # used for all internally rendered templates so you can pass
    # information with instance variables.
    # @example view_test.erb
    #   <%= render 'util/logger_popup' %>
    # @param (String) filename Relative to current template.
    def render(filename)
      if @render_call_stack.size > 100
        # Since nobody sane would recurse through here, this mainly
        # finds a render self that you might get after a copy and paste
        raise TemplateCallStackTooDeepError 
      elsif @render_call_stack.size > 0
        # Hooray for relative paths and easily movable files
        filename = File.expand_path(filename, File.dirname(@render_call_stack.last))
      else
        # Underbar templates are partials by convention; keep them from rendering at root
        filename = File.expand_path(filename)
        raise TemplateNotFoundError if File.basename(filename) =~ /^_/
      end
      @render_call_stack.push filename
      ext = File.extname(filename)
      files1 = [filename]
      files1 << filename + '.html' if ext == ''
      files1 << filename.sub(/.html$/,'') if ext == '.html'
      files1.each do |filename1|
        Googly.config.engines.each do |ext, engine|
          files2 = [filename1+ext]
          files2 << filename1.gsub(/.html$/, ext) if File.extname(filename1) == '.html'
          unless filename1 =~ /^_/ or @render_call_stack.size == 1
            files2 = files2 + files2.collect {|f| "#{File.dirname(f)}/_#{File.basename(f)}"} 
          end
          files2.each do |filename2|
            if File.file?(filename2) and File.readable?(filename2)
              if @render_call_stack.size == 1
                response.header["Content-Type"] = Rack::Mime.mime_type(File.extname(filename1), 'text/html')
              end
              result = engine.call self, filename2
              @render_call_stack.pop
              return result
            end
          end
        end
      end
      raise TemplateNotFoundError
    end
    
    # The Google Closure base.js script.
    # If you use this instead of a static link, you are free to relocate
    # the Google Closure library without updating every html fixture page.
    # @example view_test.erb
    #  <script src="<%= goog_base_js %>"></script>
    def goog_base_js
      Googly.deps.base_js(env)
    end
    
    # @todo this is going to be the new way of compiling
    # Run a compiler job.  Accepts every option that compiler.jar supports.
    # Also adds support for two new options:
    # * --ns -- includes all files from a namespace
    # * --compilation_level CONCATENATION -- A simple concat, now the default.
    # Please see {Compilation} for more information.
    # @example myapp.js.erb
    #   <%= compile %w{--ns myapp.HelloWorld --compilation_level ADVANCED_OPTIMIZATIONS} %>
    # @param [Array<String>]
    # @return [Compilation]
    def compile(*args)
      #Compilation.new(*args)
    end

    # Helper for URL escaping.
    # @param [String]
    # @return [String]
    def escape(s)
      Rack::Utils.escape(s)
    end

    # Helper and alias for HTML escaping.
    # @param [String]
    # @return [String]
    def escape_html(s)
      Rack::Utils.escape_html(s)
    end
    alias :h :escape_html
    
  end
  
end
