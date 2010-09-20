#\ -w -p 3000

#TODO sass middleware

require 'rubygems'
gem 'googly'

Googly.add_route('/', '.')
Googly.add_route('/goog', :goog)
Googly.add_route('/myapp', 'myapp')
run Googly
