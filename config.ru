#\ -w -p 3000

use Rack::Lint
use Rack::Reloader, 0

require File.join(File.dirname(__FILE__), 'lib', 'googly.rb')
Googly.add_route('/', File.join(Googly.config.base_path, 'public'))
Googly.add_route('/google', File.join(Googly.config.base_path, 'closure-library'))
Googly.add_route('/js_src', File.join(Googly.config.base_path, 'app', 'javascripts'))
run Googly

print "Your javascript is about to become googly!\n"
