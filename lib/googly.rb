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


require 'ostruct'
require 'tmpdir'

# Googlyscript can be run with rackup using a config.ru, installed
# directly into a Rails 3 route file, or adapted to anything that
# provides a rack environment.
# @example config.ru
#   #\ -w -p 9009
#   require 'rubygems'
#   gem 'googlyscript'
#   require 'googly'
#   Googly.add_route('/', './public')
#   Googly.add_route('/goog', :goog)
#   Googly.add_route('/myapp', './src/myapp')
#   Googly.config.makefile = './src/makefile.yml'
#   run Googly
# @example makefile.yml
#   myapp:
#     require:
#       - myapp.HelloWorld
#     test: &base_options
#       - [--compilation_level, ADVANCED_OPTIMIZATIONS]
#     build: 
#       - *base_options
#       - [--js_output_file, myapp.js]
class Googly
  
  googly_lib_path = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(googly_lib_path) if !$LOAD_PATH.include?(googly_lib_path)
  
  autoload(:Responses, 'googly/responses')
  autoload(:BeanShell, 'googly/beanshell')
  autoload(:Compiler, 'googly/compiler')
  autoload(:Source, 'googly/source')
  autoload(:Deps, 'googly/deps')
  autoload(:Erb, 'googly/erb')
  autoload(:Haml, 'googly/haml')
  autoload(:Sass, 'googly/sass')

  # Singleton
  class << self
    private :new
    protected
    def method_missing(*args, &block)
      @@instance ||= new
      @@instance.send(*args, &block)
    end
  end
  
  # Filesystem location of the Googlyscript install.
  # Typically, where the gem was installed.  This is mainly used
  # internally but may be useful for experimental configurations.
  # @return [String]
  attr_reader :base_path

  # These need to be set before the rack server is called for the first time.
  # === Attributes:
  # - (String) *makefile* -- Full path to the yaml makefile.
  # - (String) *java* -- default: "java" -- Your Java executable.
  # - (String) *compiler_jar* -- A compiler.jar to use instead of the one in the gem.
  # - (String) *tmpdir* -- Temp directory to use instead of the OS default.
  # @return [OpenStruct]
  attr_reader :config
  
  # Maps javascript sources and static files to the Googlyscript http server.
  # @example Basic routing:
  #   Googly.add_route('/', './public')
  #   Googly.add_route('/goog', :goog)
  # @example Advanced routing:
  #   Googly.add_route('/myapp', :dir => my_dir, :source => true, :deps => true)
  # @overload add_route(path, directory)
  # @overload add_route(path, built_in)
  # @overload add_route(path, options)
  # @param (String) path 
  #        http server mount point
  # @param (String) directory
  # @param (Symbol) built_in :goog, :goog_vendor, :googly, :public
  # @param (Hash) options
  # @option options [String] :dir Location in the filesystem to be mounted
  #         by the http server.
  # @option options [Boolean] :source (false) Does the directory
  #         contain javascript sources?  You would leave this false if,
  #         for example, you needed to mount a folder containing
  #         a large enough number of image files to slow a directory glob.
  # @option options [Boolean, String] :deps (false) This will serve
  #         path+"/deps.js" when true.  Set to a string if you
  #         want something other than "/deps.js".  The intent is to override
  #         the static deps.js in the google closure library with a dynamic 
  #         version that is always up-to-date.
  def add_route(path, options)
    #TODO something about duplicate mount points
    raise "path must start with /" unless path =~ %r{^/}
    path = '' if path == '/'
    raise "path must not end with /" if path =~ %r{/$}
    # Easy routing makes assumptions
    if options.kind_of? Symbol
      options = built_ins[options]
    elsif options.kind_of? String
      if path == ''
        options = {:dir => options, :hidden => true}
      elsif path == "/goog"
        options = {:dir => options, :source => true, :deps => true} 
      else
        options = {:dir => options, :source => true} 
      end
    end
    options[:dir] = File.expand_path(options[:dir])
    options[:rack_stack] = rack_stack_for(path, options)
    @routes << [path, options]
    @routes.sort! {|a,b| b[0] <=> a[0]}
  end
  
  # Rack interface.
  # @param (Hash) env Rack environment.
  # @return (Array)[status, headers, body]
  def call(env)
    @rack_call_log = []
    path_info = env["PATH_INFO"]
    if path_info == '/' or path_info == '%2F' or path_info == '%2f'
      status, headers, body = call_root(env)
    else
      status, headers, body = call_route(env)
    end
    return not_found if status == 404 and headers["X-Cascade"] == "pass"
    [status, headers, body]
  end
  
  # Run Java command in a REPL (read-execute-print-loop).
  # This keeps Java running so you only pay the startup cost on the first job.
  # @param (String) command Rack environment.
  # @return (Array)[stdout, stderr]
  def java(command)
    @beanshell ||= BeanShell.new
    @beanshell.run(command)
  end
  

  protected
  
  def initialize 
    @routes = Array.new
    @base_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @config = OpenStruct.new
    config.java = 'java'
    config.compiler_jar = File.join(base_path, 'closure-compiler', 'compiler.jar')
    config.tmpdir = Dir.tmpdir
    config.haml = {}
    @source = Source.new(@routes)
    @compiler = Compiler.new(@source, config)
  end
  
  def not_found
    if @rack_call_log.length == 0
      body = "404 Not Found.\nNo rack servers called.  Did you add routes?\n"
    else
      body = "404 Not Found.\nTried: #{@rack_call_log.join(', ')}.\n"
    end
    [404, {"Content-Type" => "text/plain",
       "Content-Length" => body.size.to_s,
       "X-Cascade" => "pass"},
     [body]]
  end


  def call_root(env)
    status, headers, body = [ 404, {'X-Cascade' => 'pass'}, [] ]
    [@compiler].each do |rack_server|
      status, headers, body = rack_server.call(env)
      @rack_call_log << rack_server.class.name
      break unless headers["X-Cascade"] == "pass"
    end
    [status, headers, body]
  end


  def call_route(env)
    status, headers, body = [ 404, {'X-Cascade' => 'pass'}, [] ]
    saved_script_name = env["SCRIPT_NAME"]
    saved_path_info = env["PATH_INFO"]
    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    @routes.each do |path, options|
      if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
        env["SCRIPT_NAME"] = "#{saved_script_name}#{path}"
        env["PATH_INFO"] = Rack::Utils.escape($1)
        options[:rack_stack].each do |rack_server|
          status, headers, body = rack_server.call(env)
          @rack_call_log << rack_server.class.name
          # Rack::File from rack<V2 doesn't implement X-Cascade
          break unless headers["X-Cascade"] == "pass" or rack_server.class == Rack::File and status == 404
        end
        env["SCRIPT_NAME"] = saved_script_name
        env["PATH_INFO"] = saved_path_info
        break
      end
    end
    [status, headers, body]
  end

  
  # X-Cascade stack of rack servers
  def rack_stack_for(path, options)
    rack_stack = Array.new
    rack_stack << Deps.new(@source, options[:deps]) if options[:deps]
    rack_stack << Rack::File.new(options[:dir])
    rack_stack << Erb.new(options[:dir])
    rack_stack << Haml.new(options[:dir])
    rack_stack
  end

  def built_ins
    public_dir = File.join(base_path, 'public')
    goog_dir = File.join(base_path, 'closure-library', 'closure', 'goog')
    goog_vendor_dir = File.join(base_path, 'closure-library', 'third_party', 'closure', 'goog')
    googly_dir = File.join(base_path, 'src', 'javascript')
    {
      :public => {:dir => public_dir, :hidden => true},
      :goog => {:dir => goog_dir, :source => true, :deps => true},
      :goog_vendor => {:dir => goog_vendor_dir, :source => true, :deps => true},
      :googly => {:dir => googly_dir, :source => true},
    }
  end
  
end

