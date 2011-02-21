#\ -p 8080 -E none
require 'closure'
use Rack::CommonLogger
use Closure::Middleware, File.join(Closure.base_path, 'scripts', 'welcome', 'index')
run Rack::File.new File.join(Closure.base_path, 'scripts', 'welcome')
