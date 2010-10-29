require 'rubygems'
gem 'haml'
require 'haml'
require 'rack/file'

class Googly

  # @todo This is a work in progress.

  class Haml < Rack::File

    def initialize(options)
      @options = options
    end

    def call(env)
      path_info = Rack::Utils.unescape(env["PATH_INFO"])

      return forbidden  if path_info.include? ".."

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
