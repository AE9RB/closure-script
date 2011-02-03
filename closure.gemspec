# -*- encoding: utf-8 -*-
require File.expand_path("../lib/closure/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "closure"
  s.version     = Closure::VERSION
  s.platform    = Gem::Platform::RUBY
  s.homepage    = "https://github.com/dturnbull/closure-script"
  s.summary     = "Closure Script for Google Closure Compiler, Library, and Templates."

  s.required_rubygems_version = ">= 1.3"
  # s.rubyforge_project         = "closure-script"
  
  s.add_dependency 'rack', '>= 1.0.0'

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.test_files   = `git ls-files`.split("\n").map{|f| f =~ /^(test\/.*_test.rb)$/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
