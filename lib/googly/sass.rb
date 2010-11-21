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

  # Googlyscript can easily respond to hundreds of requests
  # per second, but not with Sass::Plugin::Rack in the stack. 
  # This works exactly like Sass::Plugin::Rack except you
  # can limit how often it runs.  
  # @example config.ru
  #  require 'googlyscript'
  #  require 'sass/plugin'
  #  Sass::Plugin.options[:template_location] = {in_dir => out_dir}
  #  use Googly::Sass, 10

  class Sass
    
    # @param app [#call] The Rack application
    # @param dwell [Float] in seconds.  
    def initialize(app, dwell = 1.0)
      @app = app
      @dwell = dwell
      @check_after = Time.now.to_f
    end

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
    def call(env)
      if Time.now.to_f > @check_after
        require 'sass/plugin'
        ::Sass::Plugin.check_for_updates
        @check_after = Time.now.to_f + @dwell
      end
      @app.call(env)
    end
    
  end
end
