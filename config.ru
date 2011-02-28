#\ -p 8080 -E none

closure_lib_path = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)
require 'closure'

# use Rack::CommonLogger # slow
use Rack::Reloader, 1
use Rack::Lint # slow

Dir.chdir 'scripts'
eval(File.read('config.ru'), binding, 'config.ru')

print "Closure Script development server started.\n"
print "http://localhost:8080/\n"
