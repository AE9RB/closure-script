require 'rubygems'
require 'haml'

class Googly

  class Haml

    def initialize(options)
      @options = options
    end

    def call(env)
      path_info = Rack::Utils.unescape(env["PATH_INFO"])

      template = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'public', path_info + '.haml'))
      haml = ::Haml::Engine.new(File.read(template))
      body = haml.render
      [200, {"Content-Type" => "text/html",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
  end
end
