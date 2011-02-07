#\ -p 9009 -E none
# This is the rackup for developers working on (not with) Closure Script.

closure_lib_path = File.expand_path(File.dirname(__FILE__), 'lib')
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)
require 'closure'

Closure.add_source :goog, '/goog'
Closure.add_source :goog_vendor, '/goog_vendor'
Closure.add_source :soy, '/soy_js'
Closure.add_source File.join(Closure.base_path, 'scripts'), '/'
Closure.config.haml[:format] = :html5

use Rack::CommonLogger # slow
use Rack::Reloader, 1
use Rack::Lint # slow
use Rack::ShowExceptions
use Closure::Templates, %w{
  --shouldProvideRequireSoyNamespaces
  --cssHandlingScheme goog
  --shouldGenerateJsdoc
  --outputPathFormat {INPUT_DIRECTORY}{INPUT_FILE_NAME_NO_EXT}.js
  scripts/**/*.soy
}
use Closure::Middleware, File.join(Closure.base_path, 'scripts', 'index.html')

# Yard will have a better Middleware in a future release.
# This maps /(root), /docs and /list (maybe others).
# Closure::Middleware serves the home page because it's run first.
require 'yard'
`rm -r .yardoc 2>/dev/null` # Because Yard doesn't mark and sweep for deletes.
YARD::CLI::Yardoc.new.run('-c', '-n', '--no-stats') # Must be run once before starting.
use YARD::Server::RackMiddleware, {
  :libraries => {'closure' => [YARD::Server::LibraryVersion.new('closure', nil, '.yardoc')]},
  :options => {:incremental => true}
}

run Rack::File.new File.join(Closure.base_path, 'scripts')

print "Closure Script development server started.\n"
