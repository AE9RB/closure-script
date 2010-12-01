#\ -p 9009 -E none
# This is the rackup for developers working on (not with) Googlyscript.

require File.join(File.dirname(__FILE__), 'lib', 'googlyscript.rb')

Googly.script '/goog', :goog
Googly.script '/goog_vendor', :goog_vendor
Googly.script '/soy_js', :soy_js
Googly.script '/', File.join(Googly.base_path, 'scripts')
Googly.config.haml[:format] = :html5

use Rack::CommonLogger # slow
use Rack::Reloader, 1
use Rack::Lint # slow
use Rack::ShowExceptions
use Googly::Soy, %w{
  --shouldProvideRequireSoyNamespaces
  --cssHandlingScheme goog
  --shouldGenerateJsdoc
  --outputPathFormat {INPUT_DIRECTORY}{INPUT_FILE_NAME_NO_EXT}.js
  scripts/**/*.soy
}
use Googly::Middleware, File.join(Googly.base_path, 'scripts', 'index.html')

# Yard will have a better Middleware in a future release.
# This maps /(root), /docs and /list (maybe others).
# Googly::Middleware serves the home page because it's run first.
require 'yard'
`rm -r .yardoc 2>/dev/null` # Because Yard doesn't mark and sweep for deletes.
YARD::CLI::Yardoc.new.run('-c', '-n', '--no-stats') # Must be run once before starting.
use YARD::Server::RackMiddleware, {
  :libraries => {'googly' => [YARD::Server::LibraryVersion.new('googly', nil, '.yardoc')]},
  :options => {:incremental => true}
}

run Rack::File.new File.join(Googly.base_path, 'scripts')

print "Scripting engaged.  Caution: Googlies bond instantly to skin.\n"
