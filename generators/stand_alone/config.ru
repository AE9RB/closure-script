#\ -p 9009 -E none

require 'rubygems'
require 'googly'

Googly.script('/goog', :goog)
Googly.script('/myapp', 'myapp')
Googly.config.makefile = 'makefile.yml'

use Rack::ShowExceptions
use Googly::Middleware
run Rack::File.new '.'

print "Running. (silently)\n"
