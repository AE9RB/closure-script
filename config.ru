#\ -w -p 9009 -E none
# This is the rackup for developers working on (not with) Googlyscript.

require File.join(File.dirname(__FILE__), 'lib', 'googly.rb')
require 'sass/plugin'

Sass::Plugin.options[:template_location] = File.join(Googly.base_path, 'src', 'stylesheet')
Sass::Plugin.options[:css_location] = File.join(Googly.base_path, 'public', 'stylesheets')
Sass::Plugin.options[:cache_location] = File.join(Googly.base_path, 'tmp')

Googly.script('/goog', :goog)
Googly.script('/goog_vendor', :goog_vendor)
Googly.script('/googly', :googly)
Googly.config.makefile = File.join(Googly.base_path, 'src', 'javascript', 'makefile.yml')
Googly.config.tmpdir = File.join(Googly.base_path, 'tmp')
Googly.config.haml[:format] = :html5

# use Rack::CommonLogger # slow, adds ~20% to goog.editor Demo page load
use Rack::Reloader, 0
use Rack::Lint
use Rack::ShowExceptions
use Googly::Sass
use Googly::Middleware
run Rack::File.new File.join(Googly.base_path, 'public')

print "Your javascript is about to become googly!\n"
