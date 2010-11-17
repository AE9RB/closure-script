#\ -p 9009 -E none

require 'rubygems'
require 'googly'

Googly.add_source('/goog', :goog)
Googly.add_source('/myapp', 'myapp')
Googly.config.makefile = 'makefile.yml'

use Rack::ShowExceptions
use Googly::Middleware
run Rack::File.new '.'

print "Running. (silently)\n"
