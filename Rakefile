closure_lib_path = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)
require 'closure'
require 'warbler'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'yard'
require 'rack'
require 'haml'

#TODO add java build (see example in warbler makefile)

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

gem_task = Rake::GemPackageTask.new(gem_spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

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
  config.includes = FileList[".yardopts", 'LICENSE', 'README.md']

  config.gems << "jruby-jars"
  config.gems << "jruby-rack"
  config.gems << "haml"
  
  config.features = %w(executable)
  config.bundler = false

  config.webxml.booter = :rack
  config.webxml.rackup = <<-EOS
    require 'rubygems'
    require 'java'
    Dir.chdir(java.lang.System.getProperty('user.dir'))
    eval(File.read('config.ru'), binding, 'config.ru')
  EOS
  
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
end

Warbler::Task.new("war", war_config)

desc 'Broken, use clobber_package.'
task 'war:clean' do
  # warbler maybe should support autodeploy_dir for this
end

# WAR server

desc 'java server'
task 'war:run' do
  war_file = File.join war_config.autodeploy_dir, war_config.war_name + '.war'
  unless File.exist?(war_file)
    print "ERROR: Build #{war_file} with `rake war` first.\n"
    exit 1
  end
  exec "#{Closure.config.java} -jar #{war_file}"
end

# DOCS

DOCS_GEMS = %w{closure rack haml}

DOCS_GEMS.each do |gem_name|
  if gem_name == 'closure'
    spec = nil
  else
    spec = Gem.loaded_specs[gem_name]
    raise "Gem #{gem_name} not loaded." unless spec
  end
  if gem_name == 'rack'
    extra = '- SPEC'
  else
    extra = ''
  end
  desc 'Generate YARD Documentation'
  task "docs:#{gem_name}" do
    db_dir = File.expand_path(".yardoc_#{gem_name}")
    out_dir = File.expand_path("scripts/docs/#{gem_name}")
    save_dir = Dir.getwd
    Dir.chdir(spec.full_gem_path) if spec
    `yardoc --db #{db_dir} --output-dir #{out_dir} #{extra}`
    Dir.chdir save_dir
  end
end

desc 'Generate all documentation'
task 'docs' => DOCS_GEMS.collect {|s| "docs:#{s}"}

