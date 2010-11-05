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
  autoload(:Sass, 'googly/sass')
  autoload(:Route, 'googly/route')
  
  include Responses

  # Singleton
  class << self
    private :new
    protected
    def method_missing(*args, &block)
      @@instance ||= new
      @@instance.send(*args, &block)
    end
  end
  
  # These need to be set before the rack server is called for the first time.
  # === Attributes:
  # - (String) *makefile* -- Full path to the yaml makefile.
  # - (String) *java* -- default: "java" -- Your Java executable.
  # - (String) *compiler_jar* -- A compiler.jar to use instead of the one in the gem.
  # - (String) *tmpdir* -- Temp directory to use instead of the OS default.
  # - (Hash) *haml* -- Options hash for haml engine.
  # @return [OpenStruct]
  def config
    return @config if @config
    @config = OpenStruct.new
    @config.java = 'java'
    @config.compiler_jar = File.join(base_path, 'closure-compiler', 'compiler.jar')
    @config.tmpdir = Dir.tmpdir
    @config.haml = {}
    @config
  end
  
  # Maps javascript sources and static files to the Googlyscript http server.
  # @example Basic routing:
  #   Googly.add_route('/', './public')
  #   Googly.add_route('/goog', :goog)
  #   Googly.add_route('/myapp', my_dir)
  # @example Advanced routing:
  #   Googly.add_route('/', :dir => my_dir, :source => true, :deps => '/goog/deps.js')
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
    options[:route] ||= Route.new(options[:dir], options[:deps], @source)
    @routes << [path, options]
    @routes.sort! {|a,b| b[0] <=> a[0]}
  end
  
  # For Rakefile tasks or other automation.
  # @see Compiler#compile_js
  def compile_js(build, type=nil)
    @compiler.compile_js(build, type)
  end
  
  # Run Java command in a REPL (read-execute-print-loop).
  # This keeps Java running so you only pay the startup cost on the first job.
  # It will have compiler.jar and googly.jar loaded.
  # @param (String) command Rack environment.
  # @return (Array)[stdout, stderr]
  def java(command)
    @beanshell ||= BeanShell.new
    @beanshell.run(command)
  end

  # Filesystem location of the Googlyscript install.
  # Typically, where the gem was installed.  This is mainly used
  # internally but may be useful for experimental configurations.
  # @return [String]
  attr_reader :base_path
    
  # Rack interface.
  # @param (Hash) env Rack environment.
  # @return (Array)[status, headers, body]
  def call(env)
    path_info = env["PATH_INFO"]
    if path_info == '/' or path_info == '%2F' or path_info == '%2f'
      call_root(env)
    else
      call_routes(env)
    end
  end
  

  protected

  
  def initialize 
    @routes = Array.new
    @base_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @source = Source.new(@routes)
    @compiler = Compiler.new(@source, config)
  end
  

  def call_root(env)
    status, headers, body = not_found
    [@compiler].each do |rack_server|
      status, headers, body = rack_server.call(env)
      break unless headers["X-Cascade"] == "pass"
    end
    [status, headers, body]
  end


  def call_routes(env)
    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    @routes.each do |path, options|
      if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
        return options[:route].call(env, $1)
      end
    end
    not_found
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

