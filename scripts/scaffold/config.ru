#\ -p 8080 -E none
# The above line is processed by `rackup` for gem users.
# It is ignored if you start the server with `java -jar closure.war`.
# Changes to this file always require a server restart.
require 'closure'

# The built-in Closure Library is great for getting started.
Closure.add_source :goog, '/goog'
Closure.add_source :goog_vendor, '/goog_vendor'
# But you may need a different version as your project matures.
# Closure.add_source '../closure-library/closure/goog', '/goog'
# Closure.add_source '../closure-library/third_party/closure/goog', '/goog_vendor'

# More useful built-ins.
Closure.add_source :soy, '/soy'
Closure.add_source :docs, '/docs'
Closure.add_source :externs

# Everything in the current folder will be served as root.
Closure.add_source '.', '/'

# Ruby users may need to be specific about which java to use.
# This is not used under JRuby or when running the .war server.
# Closure.config.java = 'java'

# Feel free to change to your own compilers.
# Closure.config.compiler_jar = 'closure-library/compiler.jar'
# Closure.config.soy_js_jar = 'closure-templates/SoyToJsSrcCompiler.jar'

# The Closure middleware and a simple file server go last.
use Closure::Middleware, 'index'
run Rack::File.new '.'
print "STARTED: http://localhost:8080/\n"
