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
  
  # This is Rack middleware to show Ruby exceptions.  It is automatically loaded when
  # using Closure::Middleware.  It works very much like Rack::ShowExceptions but will
  # use the Javascript console when it can detect the request was for javascript.
  
  class ShowExceptions
    
    # @private - internal use only
    class Javascript
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue StandardError, LoadError, SyntaxError => e
        raise e unless env[Script::ENV_ERROR_CONTENT_TYPE] == 'application/javascript'
        body = 'try{console.error('
        body += '"Ruby Exception: %s\n\n", '
        body += "#{e.class.to_s.dump}, "
        body += "#{e.message.dump}, "
        body += '"\n\n", '
        body += "#{e.backtrace.join("\n").dump}"
        body += ')}catch(err){}'
        body
        [200,
         {"Content-Type" => "application/javascript",
          "Content-Length" => body.size.to_s},
         [body]]
      end
    end
    
    # @private - internal use only
    class Html < Rack::ShowExceptions
      # We may implement our own someday
    end
  
    def initialize(app)
      @app = Html.new(Javascript.new(app))
    end

    def call(env)
      @app.call(env)
    end
  end

end