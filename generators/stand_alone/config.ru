#\ -w -p 9009

require 'rubygems'
gem 'googlyscript'
require 'googly'

Googly.add_route('/', '.')
Googly.add_route('/goog', :goog)
Googly.add_route('/myapp', 'myapp')
Googly.config.makefile = 'makefile.yml'
run Googly
