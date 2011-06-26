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
  s.homepage    = 'https://github.com/dturnbull/closure-script'
  s.summary     = "Google Closure Compiler, Library, Script, and Templates."

  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency 'rack', '>= 1.0.0'
  
  dirs = %w{beanshell closure-compiler closure-templates docs externs lib scripts test}
  s.require_path = 'lib'
  s.files        = Dir.glob("{#{dirs.join ','}}/**/*")
  s.files       += %w(LICENSE README.md)
  s.test_files   = Dir.glob("test/**/*").map{|f| f =~ /^(test\/.*_test.rb)$/ ? $1 : nil}.compact
end
