# -*- encoding: utf-8 -*-
require File.expand_path("../lib/googly/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "googlyscript"
  s.version     = Googly::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = []
  s.email       = []
  s.homepage    = "http://github.com/dturnbull/googlyscript"
  s.summary     = "Google Closure"
  s.description = "A tool for developing Javascript with Google Closure."

  s.required_rubygems_version = ">= 1.3"
  s.rubyforge_project         = "googlyscript"
  
  s.add_dependency 'rack'

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^(bin\/.*)/ ? $1 : nil}.compact
  s.test_files   = `git ls-files`.split("\n").map{|f| f =~ /^(test\/.*_test.rb)$/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
