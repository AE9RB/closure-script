#\ -p 9009 -E none

require 'rubygems'
require 'googly'

Googly.add_route('/', '.')
Googly.add_route('/goog', :goog)
Googly.add_route('/myapp', 'myapp')
Googly.config.makefile = 'makefile.yml'

use Rack::ShowExceptions
run Googly

print "Running. (silently)\n"
