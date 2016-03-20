# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'closure'

Gem::Specification.new do |s|
  s.name        = "closure"
  s.version     = Closure::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['David Turnbull']
  s.email       = ['dturnbull@gmail.com']
  s.homepage    = 'https://github.com/AE9RB/closure-script'
  s.summary     = "Google Closure Compiler, Library, Script, and Templates."

  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency 'rack', '>= 1.0.0'

  dirs = %w{beanshell bin closure-compiler closure-templates lib docs/closure}
  dirs += Dir.glob('scripts/*') - %w{scripts/closure-library scripts/fixtures}
  s.require_path = 'lib'
  s.files        = Dir.glob("{#{dirs.join ','}}/**/*")
  s.files       += %w(LICENSE README.md docs/index.erb docs/SCRIPT.md)
  s.files       += Dir.glob('scripts/*')
  s.executables  = ['closure-script']
end
