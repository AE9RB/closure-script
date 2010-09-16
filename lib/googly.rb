require 'ostruct'

class Googly
  
  # Rack Singleton
  class << self
    private :new
    def instance
      @@instance ||= new
    end
  protected
    def method_missing(*args, &block)
      instance.send(*args, &block)
    end
  end

  
  def add_route(mount_point, filesystem_path)
    #TODO verify mount_point slashes
    #TODO something about duplicate mount points
    routes << [mount_point, Rack::File.new(filesystem_path)]
    routes.sort! {|a,b| b[0] <=> a[0]}
  end
  
  
  def call(env)
    status, headers, body = [ 500, {'Content-Type' => 'text/plain'}, "Internal Server Error" ]
    save_path_info = env["PATH_INFO"]
    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    routes.each do |path, rack_file|
      path = '' if path == '/'
      if path_info =~ %r{^#{Regexp.escape(path)}(/.*)}
        env["PATH_INFO"] = $1
        status, headers, body = rack_file.call(env)
        env["PATH_INFO"] = save_path_info
        break
      end
    end
    return [status, headers, body]
  end


  def config
    unless @config
      @config = OpenStruct.new
      @config.base_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
      @config.compiler_jar = File.join(@config.base_path, 'closure-compiler', 'compiler.jar')
      closure_bin_build = File.join(@config.base_path, 'closure-library', 'closure', 'bin', 'build')
      @config.depswriter = File.join(closure_bin_build, 'depswriter.py')
      @config.closurebuilder = File.join(closure_bin_build, 'closurebuilder.py')
    end
    @config
  end
  
  private
  
  def routes
    @routes ||= Array.new
  end
  
end

