class Googly

  # Basic support for Haml.

  class Haml
    
    include Responses

    def initialize(root)
      @root = root
    end

    def call(env)
      
      path_info = Rack::Utils.unescape(env["PATH_INFO"])

      return forbidden if path_info.include? ".."
      
      template = Errno::ENOENT
      filename = path_info.gsub(/\.html$/, '.haml')
      if filename != path_info
        filename = File.join(@root, filename)
        template = File.read(filename) rescue Errno::ENOENT
      end
      if template == Errno::ENOENT
        filename = File.join(@root, path_info + '.haml')
        template = File.read(filename) rescue Errno::ENOENT
      end
      if template == Errno::ENOENT
        filename = File.join(@root, path_info + '.html.haml')
        template = File.read(filename) rescue Errno::ENOENT
      end
      return not_found if template == Errno::ENOENT

      haml_options = Googly.config.haml_options || {}
      haml_options = haml_options.merge(:filename => filename)
      
      body = ::Haml::Engine.new(template, haml_options).render
      [200, {"Content-Type" => "text/html",
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
  end
end
