closure_lib_path = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)

begin
  require 'bundler/setup'
rescue Exception, LoadError => e
  puts "ERROR: Try using `bundle exec rake`"
  exit 1
end

# Although psych is faster, it fails.
YAML::ENGINE.yamler='syck' if defined?(YAML::ENGINE)

require 'closure'
require 'rubygems/package_task'
require 'rake/testtask'
require 'warbler'


# All docs are distributed with the war
# Only closure is packaged with the gem
DOCS = %w{closure erb rack haml kramdown}

#TODO add java build (see example in warbler makefile)

# SERVER

desc 'Start the Closure Script server'
task 'server' do
  require 'rack'
  Rack::Server.start :config => "config.ru"
end

desc 'Start the Closure Script welcome server'
task 'welcome' do
  mkdir_p 'tmp' if !File.exist?('tmp')
  rm_r Dir.glob 'tmp/*'
  tmp = File.expand_path 'tmp'
  chdir tmp
  Closure.welcome
end

# TEST

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

# GEM

gem_spec = Gem::Specification.load 'closure.gemspec'

task 'gem:ensure_closure_docs' do
  unless File.exists? "docs/closure/index.html"
    print "ERROR: Docs for closure not found.\n"
    exit 1
  end
end
task 'gem' => 'gem:ensure_closure_docs'

gem_task = Gem::PackageTask.new(gem_spec) {}

# WAR

# You win, Warbler. I will cheat now.
module Warbler
  module Traits
    class Gemspec
      def self.detect?
        false
      end
    end
  end
end

war_config = Warbler::Config.new do |config|
  config.autodeploy_dir = gem_task.package_dir
  config.jar_name = "closure-#{gem_spec.version}"

  config.dirs = %w(
    closure-compiler
    closure-templates
    lib
    scripts
    docs
  )
  config.excludes += FileList['scripts/closure-library/**/*', 'scripts/fixtures/**/*']
  
  config.bundler = false
  config.gems << Gem.loaded_specs['jruby-jars']
  config.gems << Gem.loaded_specs['jruby-rack']
  config.gems << Gem.loaded_specs['haml']
  config.gems << Gem.loaded_specs['kramdown']
  
  config.features = %w(executable)
  config.webxml.booter = :rack

  # A clean binding is more important than being dry.
  config.webxml.rackup = <<-EOS
    require 'rubygems'
    require 'java'
    $LOAD_PATH.unshift File.expand_path('lib')
    Dir.chdir(java.lang.System.getProperty('user.dir'))
    if File.exist? File.join java.lang.System.getProperty('user.dir'), 'config.ru'
      eval(File.read('config.ru'), binding, 'config.ru')
    else
      require 'closure'
      ENV["CLOSURE_SCRIPT_WELCOME"] = 'true'
      eval(File.read(File.join Closure.base_path, 'scripts/config.ru'), binding, 'config.ru')
    end
  EOS
  
  # Closure Script is thread-safe and multithreaded by default.
  # We choose to be bound in a single runtime to allow Scripts easy
  # access to globals for background processing with Ruby threads.
  config.webxml.jruby.min.runtimes = 1  
  config.webxml.jruby.max.runtimes = 1
  
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
  DOCS.each do |gem_name|
    unless File.exists? "docs/#{gem_name}/index.html"
      print "ERROR: Docs for #{gem_name} not found.\n"
      exit 1
    end
  end
end

Warbler::Task.new("war", war_config)

desc 'Broken, use clobber_package'
task 'war:clean' do
  # warbler maybe should support autodeploy_dir for this
end

desc 'Start the .war welcome server'
task 'war:server' do
  war_file = File.expand_path File.join war_config.autodeploy_dir, war_config.jar_name + '.war'
  unless File.exist?(war_file)
    print "ERROR: Build #{war_file} first.\n"
    exit 1
  end
  mkdir_p 'tmp' if !File.exist?('tmp')
  rm_r Dir.glob 'tmp/*'
  tmp = File.expand_path 'tmp'
  chdir tmp
  ENV.delete 'RUBYOPT' # detach from bundler
  exec "java -jar #{war_file}"
end

# DOCS

DOCS.each do |gem_name|
  if %w{closure}.include? gem_name
    base_path = '.'
  elsif %w{erb}.include? gem_name
    # Anywhere yard won't magically find the wrong README
    base_path = 'docs'
  else
    spec = Gem.loaded_specs[gem_name]
    unless spec
      print "ERROR: Gem #{gem_name} not loaded." 
      exit 1
    end
    base_path = spec.full_gem_path
  end
  if gem_name == 'rack'
    extra = '- SPEC'
  elsif gem_name == 'erb'
    extra = '--default-return "" --hide-void-return --title ERB --no-yardopts ../vendor/erb.rb'
  elsif gem_name == 'haml'
    # Haml ships gem with incomplete docs
    # https://github.com/nex3/haml/issues/351
    haml_ref_file = File.expand_path("vendor/HAML_REFERENCE.md")
    extra = "--main #{haml_ref_file.dump} - README.md MIT-LICENSE #{haml_ref_file.dump}"
  else
    extra = ''
  end
  desc "Generate #{gem_name} documentation"
  task "docs:#{gem_name}" do
    db_dir = File.expand_path(".yardoc_#{gem_name}")
    rm_rf db_dir # ensure full build
    out_dir = File.expand_path("docs/#{gem_name}")
    rm_rf out_dir
    save_dir = Dir.getwd
    Dir.chdir(base_path)
    `yardoc --db #{db_dir} --output-dir #{out_dir} #{extra}`
    Dir.chdir save_dir
    rm_rf db_dir # cleanup
  end
end

desc 'Generate all documentation'
task 'docs' => DOCS.collect {|s| "docs:#{s}"}

