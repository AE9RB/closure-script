closure_lib_path = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)
require 'closure'
require 'warbler'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'yard'

# All docs are distributed with the war
# Only closure is packaged with the gem
DOCS_GEMS = %w{closure rack haml}

# These versions are important mostly for war packaging.
# Gem users are free to mix and match any sensible versions.
HAML_VER = '= 3.0.25' # check for dwell on sass when upgrading
JRUBY_JARS_VER = '= 1.5.6'
# jruby-rack embeds a specific version of rack, keep in sync
JRUBY_RACK_VER = '= 1.0.6'
RACK_VER = '= 1.2.1'

gem 'haml', HAML_VER
gem 'rack', RACK_VER

#TODO add java build (see example in warbler makefile)

# SERVER

desc 'Start the Closure Script server'
task 'server' do
  require 'rack'
  Rack::Server.start :config => "config.ru"
end

# TEST

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

# GEM

gem_spec = Gem::Specification.new do |s|
  s.name        = "closure"
  s.version     = Closure::VERSION
  s.platform    = Gem::Platform::RUBY
  s.homepage    = "http://www.closure-script.com/"
  s.summary     = "Google Closure Compiler, Library, Script, and Templates."

  s.required_rubygems_version = ">= 1.3"
  s.add_dependency 'rack', '>= 1.0.0'

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.test_files   = `git ls-files`.split("\n").map{|f| f =~ /^(test\/.*_test.rb)$/ ? $1 : nil}.compact
  s.require_path = 'lib'
end

file "closure.gemspec" => ["Rakefile"] do |t|
  require 'yaml'
  open(t.name, "w") { |f| f.puts gem_spec.to_yaml }
end

task 'gem:ensure_closure_docs' do
  unless File.exists? "scripts/docs/closure/index.html"
    print "Docs for closure not built.\n"
    exit 1
  end
end
task 'gem' => 'gem:ensure_closure_docs'

gem_task = Rake::GemPackageTask.new(gem_spec) {}

# WAR

war_config = Warbler::Config.new do |config|
  config.autodeploy_dir = gem_task.package_dir
  config.war_name = "closure-#{gem_task.version}"

  config.dirs = %w(
    closure-compiler
    closure-library
    closure-templates
    lib
    scripts
  )
  config.includes = FileList['LICENSE']

  config.gems << Gem::Dependency.new("jruby-jars", JRUBY_JARS_VER)
  config.gems << Gem::Dependency.new("jruby-rack", JRUBY_RACK_VER)
  config.gems << Gem::Dependency.new("haml", HAML_VER)
  
  config.features = %w(executable)
  config.bundler = false

  config.webxml.booter = :rack
  config.webxml.rackup = <<-EOS
    require 'rubygems'
    require 'java'
    $LOAD_PATH.unshift File.expand_path('lib')
    Dir.chdir(java.lang.System.getProperty('user.dir'))
    eval(File.read('config.ru'), binding, 'config.ru')
  EOS
  
  # Include any file to create classes folder which stops a warning
  config.java_classes = FileList['Rakefile']
  
  # I can't figure out why jruby-rack has these settings.
  # Both need to be true or we often won't see the request.
  # It's silly that we have to check the filesystem on
  # every request when we know nothing will ever be found.
  config.webxml.jruby.rack.filter.adds.html = true
  config.webxml.jruby.rack.filter.verifies.resource = true
end

task 'war' do
  # warbler won't make this automatically like rake does
  dir = war_config.autodeploy_dir
  mkdir_p dir if !File.exist?(dir)
  # ensure all docs were built
  DOCS_GEMS.each do |gem_name|
    unless File.exists? "scripts/docs/#{gem_name}/index.html"
      print "Docs for #{gem_name} not built.\n"
      exit 1
    end
  end
end

Warbler::Task.new("war", war_config)

desc 'Broken, use clobber_package'
task 'war:clean' do
  # warbler maybe should support autodeploy_dir for this
end

desc 'Start the project .war server'
task 'war:server' do
  war_file = File.join war_config.autodeploy_dir, war_config.war_name + '.war'
  unless File.exist?(war_file)
    print "Build #{war_file} first.\n"
    exit 1
  end
  exec "#{Closure.config.java} -jar #{war_file}"
end

# DOCS

DOCS_GEMS.each do |gem_name|
  if gem_name == 'closure'
    spec = nil
  else
    spec = Gem.loaded_specs[gem_name]
    unless spec
      print "Gem #{gem_name} not loaded." 
      exit 1
    end
  end
  #TODO we can hijack the --readme
  if gem_name == 'rack'
    extra = '- SPEC'
  elsif gem_name == 'haml'
    extra = '- MIT-LICENSE'
  else
    extra = ''
  end
  desc 'Generate #{gem_name} documentation'
  task "docs:#{gem_name}" do
    db_dir = File.expand_path(".yardoc_#{gem_name}")
    rm_rf db_dir # ensure full build
    out_dir = File.expand_path("scripts/docs/#{gem_name}")
    rm_rf out_dir
    save_dir = Dir.getwd
    Dir.chdir(spec.full_gem_path) if spec
    `yardoc --db #{db_dir} --output-dir #{out_dir} #{extra}`
    Dir.chdir save_dir
    rm_rf db_dir # cleanup
  end
end

desc 'Generate all documentation'
task 'docs' => DOCS_GEMS.collect {|s| "docs:#{s}"}

