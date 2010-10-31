class Googly

  # Basic support for Haml.

  class Haml
    
    include Responses

    def initialize(options)
      @options = options
    end

    def call(env)
      
      path_info = Rack::Utils.unescape(env["PATH_INFO"])

      return forbidden if path_info.include? ".."
      
      template = Errno::ENOENT
      filename = path_info.gsub(/\.html$/, '.haml')
      if filename != path_info
        template = File.read(File.join(@options[:dir], filename)) rescue Errno::ENOENT
      end
      if template == Errno::ENOENT
        template = File.read(File.join(@options[:dir], path_info + '.haml')) rescue Errno::ENOENT
      end
      if template == Errno::ENOENT
        template = File.read(File.join(@options[:dir], path_info + '.html.haml')) rescue Errno::ENOENT
      end
      return not_found if template == Errno::ENOENT

      # We wait until the very last moment to load haml.
      require 'rubygems'
      gem 'haml'
      require 'haml'
      
      body = ::Haml::Engine.new(template).render
      [200, {"Content-Type" => "text/html",
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
  end
end
