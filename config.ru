#\ -w -p 3000
# This is the rackup for working on Googlyscript.
# Visit the generators folder to use Googlyscript on your project.

use Rack::Reloader, 0
use Rack::Lint
use Rack::ShowExceptions

require 'lib/googly'

require File.join(File.dirname(__FILE__), 'lib', 'googly.rb')

run Googly

print "Your javascript is about to become googly!\n"
