# Copyright 2011 The Closure Script Authors
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
require 'tempfile'

# Closure tools may be called directly, run as a stand-alone server, installed as
# middleware into a framework like Rails, or adapted to anything with a rack environment.
# @example config.ru
#   #\ -p 8080 -E none
#   require 'rubygems'
#   require 'closure'
#   Closure.add_source :goog, '/goog'
#   Closure.add_source './src/myapp', '/myapp'
#   use Rack::ShowExceptions
#   use Closure::Middleware
#   run Rack::File.new './public'

class Closure
  
  autoload(:VERSION, 'closure/version')
  autoload(:BeanShell, 'closure/beanshell')
  autoload(:Sass, 'closure/sass')
  autoload(:Script, 'closure/script')
  autoload(:Sources, 'closure/sources')
  autoload(:FileResponse, 'closure/file_response')
  autoload(:Middleware, 'closure/middleware')
  autoload(:Compiler, 'closure/compiler')
  autoload(:Server, 'closure/server')
  autoload(:Goog, 'closure/goog')
  autoload(:Templates, 'closure/templates')
  autoload(:ShowExceptions, 'closure/show_exceptions')
  

  # Filesystem location of the Closure Script install.
  # Typically, where the gem was installed.  This is mainly used
  # internally but may be useful for experimental configurations.
  # @return [String]
  def self.base_path
    @@base_path ||= File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
  

  # Scripts that are distributed with the gem.  These will help get you started quickly.
  # Closure Script isn't tied to any Google Closure release, so feel free to use whatever
  # version you want and check it in to your repository.
  BUILT_INS = {
    :goog => File.join(base_path, 'closure-library', 'closure', 'goog'),
    :goog_vendor => File.join(base_path, 'closure-library', 'third_party', 'closure', 'goog'),
    :soy => File.join(base_path, 'closure-templates'),
    :externs => File.join(base_path, 'scripts', 'externs'),
    :demos => File.join(base_path, 'scripts', 'demos'),
    :docs => File.join(base_path, 'scripts', 'docs')
  }
  
  
  # Easy config. This adds to the global instance of sources and
  # supports using the {BUILT_INS}.
  # @example
  #   Closure.add_source :goog, '/goog'
  #   Closure.add_source './myapp', '/myapp'
  # @overload script(path, directory)
  # @overload script(path, built_in)
  # @param (String) path http server mount point.
  # @param (String) directory Where the scripts are in the filesystem.
  # @param (Symbol) built_in
  def self.add_source(directory, path=nil)
    if directory.kind_of? Symbol
      dir = BUILT_INS[directory] 
      raise "Unknown built-in: #{directory}" unless dir
      directory = dir
    end
    sources.add directory, path
  end


  # This is a global instance of sources, configured with Closure.add_source()
  # and used for {Closure Script::Middleware} by default.
  # Path and directory pairs configured with Closure.add_source().
  # @return [Array]
  def self.sources
    @@sources ||= Sources.new
  end
  
  
  # Execute jar in a REPL or with JRuby
  # @private - internal use only
  # @param (String) jar Path to .jar file
  # @param (String) mainClass Class with main(String[] args)
  # @param (Array) args Arguments
  # @return (Array)[stdout, stderr]
  def self.run_java(jar, mainClass, args)
    jar = File.expand_path(jar)
    cmdout = Tempfile.new 'closure_java_out'
    cmderr = Tempfile.new 'closure_java_err'
    begin
      if defined? JRUBY_VERSION
        require 'java'
        require File.join(base_path, 'lib', 'shim.jar')
        Java::ClosureScript.run(jar, mainClass, cmdout.path, cmderr.path, args)
      else
        @@beanshell ||= BeanShell.new File.join(base_path, 'lib', 'shim.jar')
        java_opts = args.collect{|a|a.dump}.join(', ')
        cmd = "ClosureScript.run(#{jar.dump}, #{mainClass.dump}, #{cmdout.path.dump}, #{cmderr.path.dump}, new String[]{#{java_opts}});"
        @@beanshell.run(cmd)
      end
    ensure
      out = cmdout.read; cmdout.close; cmdout.unlink
      err = cmderr.read; cmderr.close; cmderr.unlink
    end
    [out, err]
  end
  
  
  # Set these before the rack server is called for the first time.
  # === Attributes:
  # - (String) *java* -- default: "java" -- Your Java executable. Not used under JRuby.
  # - (String) *compiler_jar* -- A compiler.jar to use instead of the packaged one.
  # - (String) *soy_js_jar* -- A SoyToJsSrcCompiler.jar to use instead of the packaged one.
  # - (Hash) *haml* -- Options hash for haml engine.
  # - (Array) *engines* -- Add new script engines here.
  # @return [OpenStruct]
  def self.config
    return @@config if defined? @@config
    @@config = OpenStruct.new({
      :compiler_jar => File.join(base_path, 'closure-compiler', 'compiler.jar'),
      :soy_js_jar => File.join(base_path, 'closure-templates', 'SoyToJsSrcCompiler.jar'),
      :engines => {}
    })
    if !defined? JRUBY_VERSION
      @@config.java = 'java'
    end
    # ERB
    @@config.engines['.erb'] = Proc.new do |script, filename|
      require 'erb'
      erb = ::ERB.new(File.read(filename), nil, '-')
      erb.filename = filename
      script.extend ::ERB::Util
      erb.result(script.instance_eval{binding})
    end
    # HAML
    @@config.haml = {}
    @@config.engines['.haml'] = Proc.new do |script, filename|
      require 'haml'
      options = config.haml.merge(:filename => filename)
      ::Haml::Engine.new(File.read(filename), options).render(script)
    end
    #TODO add kramdown for .md/.markdown needs render_stack param (replace filename)
    @@config
  end
  
end

