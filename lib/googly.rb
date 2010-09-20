require 'ostruct'
require 'tmpdir'

class Googly

  googly_lib_path = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(googly_lib_path) if !$LOAD_PATH.include?(googly_lib_path)
  
  autoload(:Deps, 'googly/deps')
  autoload(:Static, 'googly/static')
  autoload(:Erb, 'googly/erb')
  autoload(:Soy, 'googly/soy')
  autoload(:Haml, 'googly/haml')

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

  # Easy routes:
  # Googly.add_route('/goog', :goog)
  # Googly.add_route('/', File.join(Googly.base_path, 'public'))
  # Advanced routes (no assumptions):
  # Googly.add_route('/myapp', :dir => my_dir, :deps => :write)
  # Options:
  # :dir => filesystem dir
  # :hidden => false|true
  # :deps => false|true|:write
  # :deps_server => false|true|:no_nav
  # :soy => false|true
  # :erb => false|true
  # :haml => false|true
  def add_route(path, options)
    @routes ||= Array.new
    #TODO verify path slashes
    #TODO something about duplicate mount points
    # Easy routing makes assumptions
    if options.kind_of? Symbol
      options = built_ins[options]
    elsif options.kind_of? String
      if path == "/"
        options = {:dir => options, :hidden => true}
      elsif path == "/goog"
        options = {:dir => options, :deps => true, :deps_server => true} 
      else
        options = {:dir => options, :deps => true, :soy => true, :erb => true, :haml => true} 
      end
    end
    options[:dir] = File.expand_path(options[:dir])
    path = '' if path == '/'
    options[:rack_stack] = rack_stack_for(path, options)
    @routes << [path, options]
    @routes.sort! {|a,b| b[0] <=> a[0]}
  end
  
  
  def call(env)
    Dir.mkdir @config.tmpdir rescue Errno::EEXIST
    status, headers, body = [ 500, {'Content-Type' => 'text/plain'}, "Internal Server Error" ]
    save_path_info = env["PATH_INFO"]
    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    (@routes || default_routes).each do |path, options|
      if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
        env["PATH_INFO"] = $1
        options[:rack_stack].each do |rack_server|
          status, headers, body = rack_server.call(env)
          break unless headers["X-Cascade"] == "pass"
        end
        env["PATH_INFO"] = save_path_info
        break
      end
    end
    return [status, headers, body]
  end


  def base_path
    @base_path ||= File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end


  def config
    unless @config
      @config = OpenStruct.new
      @config.java = nil
      @config.compiler_jar = File.join(base_path, 'closure-compiler', 'compiler.jar')
      closure_bin_build = File.join(base_path, 'closure-library', 'closure', 'bin', 'build')
      @config.depswriter = File.join(closure_bin_build, 'depswriter.py')
      @config.closurebuilder = File.join(closure_bin_build, 'closurebuilder.py')
      @config.tmpdir = Dir.tmpdir
    end
    @config
  end
  
  
  private
  
  # X-Cascade stack of rack servers
  def rack_stack_for(path, options)
    rack_stack = Array.new
    rack_stack << Deps.new(path, options) if options[:deps_server]
    rack_stack << Static.new(path, options)
    rack_stack << Erb.new(path, options) if options[:erb]
    rack_stack << Soy.new(path, options) if options[:soy]
    rack_stack << Haml.new(path, options) if options[:haml]
    rack_stack
  end

  def built_ins
    public_dir = File.join(base_path, 'public')
    goog_dir = File.join(base_path, 'closure-library', 'closure', 'goog')
    goog_vendor_dir = File.join(base_path, 'closure-library', 'third_party', 'closure', 'goog')
    googly_dir = File.join(base_path, 'app', 'javascripts')
    {
      :public => {:dir => public_dir, :hidden => true},
      :goog => {:dir => goog_dir, :deps => true, :deps_server => true},
      :goog_vendor => {:dir => goog_vendor_dir, :deps => true, :deps_server => true},
      :googly => {:dir => googly_dir, :deps => true, :soy => true, :erb => true, :haml => true},
    }
  end
  
  # These routes are used until add_route is called
  def default_routes
    return @default_routes if @default_routes
    saved_routes = @routes
    @routes = Array.new
    add_route('/', :public)
    add_route('/goog', :goog)
    add_route('/goog_vendor', :goog_vendor)
    add_route('/googly', :googly)
    @default_routes = @routes
    @routes = saved_routes
    return @default_routes
  end
  
end

