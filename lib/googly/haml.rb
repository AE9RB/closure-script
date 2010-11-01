class Googly

  # Enable Haml by making ::Haml::Engine available (<tt>require 'haml'</tt>).
  # Sass works by installing Sass::Plugin::Rack as middleware.
  # @example config.ru
  #  require 'haml'
  #  Googly.config.haml[:format] = :html5
  # @example config.ru
  #  require 'sass/plugin/rack'
  #  Sass::Plugin.options[:template_location] = {in_dir => out_dir}
  #  use Sass::Plugin::Rack

  class Haml
    
    include Responses

    # @param (String) root Filesystem root.
    def initialize(root)
      @root = root
      Googly.config.haml ||= {}
    end

    # Rack interface.
    # @param (Hash) env Rack environment.
    # @return (Array)[status, headers, body]
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

      options = Googly.config.haml.merge(:filename => filename)
      
      body = ::Haml::Engine.new(template, options).render
      [200, {"Content-Type" => "text/html",
         "Content-Length" => body.size.to_s},
       [body]]
    end
    
  end
end
