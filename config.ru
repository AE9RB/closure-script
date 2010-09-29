#\ -w -p 3000
# This is the rackup for working on Googlyscript.
# Visit the generators folder to use Googlyscript on your project.

use Rack::Reloader, 0
use Rack::Lint
use Rack::ShowExceptions

require 'lib/googly'

require File.join(File.dirname(__FILE__), 'lib', 'googly.rb')

Googly.add_route('/', :public)
Googly.add_route('/goog', :goog)
Googly.add_route('/goog_vendor', :goog_vendor)
Googly.add_route('/googly', :googly)
Googly.config.makefile = File.join(Googly.base_path, 'app', 'javascripts', 'makefile.yml')
Googly.config.tmpdir = File.join(Googly.base_path, 'tmp')
run Googly

print "Your javascript is about to become googly!\n"
