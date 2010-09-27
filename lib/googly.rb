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

class Googly

  googly_lib_path = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(googly_lib_path) if !$LOAD_PATH.include?(googly_lib_path)
  
  autoload(:Responses, 'googly/responses')
  autoload(:BeanShell, 'googly/beanshell')
  autoload(:Compiler, 'googly/compiler')
  autoload(:Source, 'googly/source')
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
  
  def initialize
    
    @routes = Array.new
    
    @base_path ||= File.expand_path(File.join(File.dirname(__FILE__), '..'))

    @config = OpenStruct.new
    @config.java = 'java'
    @config.compiler_jar = File.join(base_path, 'closure-compiler', 'compiler.jar')
    @config.makefile = File.join(base_path, 'app', 'javascripts', 'makefile.yml')
    @config.deps_prepend = File.join(base_path, 'public', 'navigator.js')

    @beanshell = BeanShell.new
    @source = Source.new(@routes)
    @compiler = Compiler.new(@source, @beanshell, @config)
    
    
  end
  
  attr_reader :base_path, :config

  # Easy routes:
  # Googly.add_route('/goog', :goog)
  # Googly.add_route('/', File.join(Googly.base_path, 'public'))
  # Advanced routes (no assumptions):
  # Googly.add_route('/myapp', :dir => my_dir, :deps => true, :deps_server => true)
  # Options:
  # :dir => filesystem dir
  # :hidden => false|true
  # :deps => false|true
  # :deps_server => false|true|"path" - default path is "/deps.js"
  # :soy => false|true
  # :erb => false|true
  # :haml => false|true
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
        options = {:dir => options, :deps => true, :deps_server => true} 
      else
        options = {:dir => options, :deps => true, :soy => true, :erb => true, :haml => true} 
      end
    end
    options[:dir] = File.expand_path(options[:dir])
    options[:rack_stack] = rack_stack_for(path, options)
    @routes << [path, options]
    @routes.sort! {|a,b| b[0] <=> a[0]}
  end
  
  
  def call(env)
    
    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    if path_info == '/'
      call_root(env)
    else
      call_route(env, path_info)
    end
  end
  

  protected


  def call_root(env)
    status, headers, body = [ 500, {'Content-Type' => 'text/plain'}, "Internal Server Error" ]
    [@compiler].each do |rack_server|
      status, headers, body = rack_server.call(env)
      break unless headers["X-Cascade"] == "pass"
    end
    [status, headers, body]
  end


  def call_route(env, path_info)
    status, headers, body = [ 500, {'Content-Type' => 'text/plain'}, "Internal Server Error" ]
    saved_path_info = env["PATH_INFO"]
    @routes.each do |path, options|
      if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
        env["PATH_INFO"] = Rack::Utils.escape($1)
        options[:rack_stack].each do |rack_server|
          status, headers, body = rack_server.call(env)
          break unless headers["X-Cascade"] == "pass"
        end
        env["PATH_INFO"] = saved_path_info
        break
      end
    end
    [status, headers, body]
  end

  
  # X-Cascade stack of rack servers
  def rack_stack_for(path, options)
    rack_stack = Array.new
    rack_stack << Deps.new(@source, options[:deps_server]) if options[:deps_server]
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
  
end

