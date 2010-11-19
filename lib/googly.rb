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

# Googlyscript can be run with rackup using a config.ru, installed
# as middleware into a framework, or adapted to anything that
# provides a rack environment.
# @example config.ru
#   #\ -p 9009 -E none
#   require 'rubygems'
#   require 'googly'
#   Googly.script '/goog', :goog
#   Googly.script '/myapp', './src/myapp'
#   use Rack::ShowExceptions
#   use Googly::Middleware
#   run Rack::File.new './public'

class Googly
  
  googly_lib_path = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(googly_lib_path) if !$LOAD_PATH.include?(googly_lib_path)
  
  autoload(:BeanShell, 'googly/beanshell')
  autoload(:Sass, 'googly/sass')
  autoload(:Template, 'googly/template')
  autoload(:Deps, 'googly/deps')
  autoload(:FileResponse, 'googly/file_response')
  autoload(:Middleware, 'googly/middleware')
  autoload(:Compilation, 'googly/compilation')
  
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
  # - (String) *java* -- default: "java" -- Your Java executable.
  # - (String) *compiler_jar* -- A compiler.jar to use instead of the one in the gem.
  # - (Hash) *haml* -- Options hash for haml engine.
  # - (Array) *engines* -- Add new template engines here.
  # @return [OpenStruct]
  def config
    return @config if @config
    @config = OpenStruct.new
    @config.java = 'java'
    @config.compiler_jar = File.join(base_path, 'closure-compiler', 'compiler.jar')
    @config.haml = {}
    @config.engines = [
      ['.erb', Proc.new do |template, filename|
        require 'erb'
        erb = ::ERB.new(File.read(filename), nil, '-')
        erb.filename = filename
        erb.result(template.send(:binding))
      end],
      ['.haml', Proc.new do |template, filename|
        require 'haml'
        options = Googly.config.haml.merge(:filename => filename)
        ::Haml::Engine.new(File.read(filename), options).render(template)
      end],
    ]
    @config
  end
  
  # Maps javascript sources to the Googlyscript server and compiler.
  # @example
  #   Googly.script('/goog', :goog)
  #   Googly.script('/myapp', './myapp')
  # @overload script(path, directory)
  # @overload script(path, built_in)
  # @param (String) path 
  #        http server mount point
  # @param (String) directory
  # @param (Symbol) built_in :goog, :goog_vendor, :googly
  def script(path, directory)
    raise "path must start with /" unless path =~ %r{^/}
    path = '' if path == '/'
    raise "path must not end with /" if path =~ %r{/$}
    raise "path already exists" if @sources.find{|s|s[0]==path}
    directory = built_ins[directory] if directory.kind_of? Symbol
    raise "directory already exists" if @sources.find{|s|s[1]==directory}
    @sources << [path, File.expand_path(directory)]
    @sources.sort! {|a,b| b[0] <=> a[0]}
  end

  # Path and directory pairs configured with Googly.script().
  # @return [Array]
  attr_reader :sources
  
  # Run Java command in a REPL (read-execute-print-loop).
  # This keeps Java running so you only pay the startup cost on the first job.
  # It will have compiler.jar and googly.jar loaded.
  # @param (String) command BeanShell Java command.
  # @return (Array)[stdout, stderr]
  def java(command)
    @beanshell ||= BeanShell.new
    @beanshell.run(command)
  end

  # Access to the compiler for rake tasks and the like.
  # @return (Compilation)
  def compile(args)
    Compilation.new args, @deps
  end

  # Filesystem location of the Googlyscript install.
  # Typically, where the gem was installed.  This is mainly used
  # internally but may be useful for experimental configurations.
  # @return [String]
  attr_reader :base_path

  # An instance of {Deps} initialized with all the sources
  # that you added with Googly.script() for you to use.
  # @return [Deps]
  attr_reader :deps

  # Rack interface.
  # @param (Hash) env Rack environment.
  # @return (Array)[status, headers, body]
  def call(env)
    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    return not_found if path_info.include? ".." # unsafe

    # Check for deps.js
    status, headers, body = @deps.call(env, path_info)
    return [status, headers, body] unless headers["X-Cascade"] == "pass"

    # Then check all the sources
    @sources.each do |path, dir|
      if path_info =~ %r{^#{Regexp.escape(path)}(/.*|)$}
        filename = File.join(dir, $1)
        response = FileResponse.new(env, filename)
        if !response.found? and File.extname(path_info) == ''
          response = FileResponse.new(env, filename + '.html')
        end
        response = Template.new(env, filename).response unless response.found?
        return response.finish
      end
    end
    not_found
  end
  
  # Status 404 with X-Cascade => pass.
  # @return (Array)[status, headers, body]
  def not_found
    body = "404 Not Found\n"
    [404, {"Content-Type" => "text/plain",
           "Content-Length" => body.size.to_s,
           "X-Cascade" => "pass"},
     [body]]
  end
  

  protected

  
  def initialize 
    @base_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @sources = Array.new
    @deps = Deps.new(@sources)
  end
  

  def built_ins
    {
      :goog => File.join(base_path, 'closure-library', 'closure', 'goog'),
      :goog_vendor => File.join(base_path, 'closure-library', 'third_party', 'closure', 'goog'),
      :googly => File.join(base_path, 'src', 'script'),
    }
  end
  
end

