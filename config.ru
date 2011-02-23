#\ -p 8080 -E none

closure_lib_path = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)
require 'closure'

Closure.add_source :goog, '/goog'
Closure.add_source :goog_vendor, '/goog_vendor'
Closure.add_source :soy, '/soy'
Closure.add_source :demos, '/demos'
Closure.add_source :docs, '/docs'
Closure.add_source File.join(Closure.base_path, 'scripts', 'scaffold'), '/scaffold'
Closure.add_source :externs
Closure.config.haml[:format] = :html5

# use Rack::CommonLogger # slow
use Rack::Reloader, 1
use Rack::Lint # slow
use Closure::Middleware, File.join(Closure.base_path, 'scripts', 'index.html')
run Rack::File.new File.join(Closure.base_path, 'scripts')

print "Closure Script development server started.\n"
print "http://localhost:8080/\n"
