#\ -w -p 9009
# This is the rackup for working on Googlyscript.
# Visit the generators folder to use Googlyscript on your project.

require File.join(File.dirname(__FILE__), 'lib', 'googly.rb')
require 'haml'
require 'sass/plugin/rack'

Sass::Plugin.options[:template_location] = File.join(Googly.base_path, 'src', 'stylesheet')
Sass::Plugin.options[:css_location] = File.join(Googly.base_path, 'public', 'stylesheets')
Sass::Plugin.options[:cache_location] = File.join(Googly.base_path, 'tmp')

Googly.add_route('/', :public)
Googly.add_route('/goog', :goog)
Googly.add_route('/goog_vendor', :goog_vendor)
Googly.add_route('/googly', :googly)
Googly.config.makefile = File.join(Googly.base_path, 'src', 'javascript', 'makefile.yml')
Googly.config.tmpdir = File.join(Googly.base_path, 'tmp')
Googly.config.haml[:format] = :html5

use Rack::Reloader, 0
use Rack::Lint
use Rack::ShowExceptions
use Sass::Plugin::Rack
run Googly

print "Your javascript is about to become googly!\n"
