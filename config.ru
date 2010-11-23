#\ -p 9009 -E none
# This is the rackup for developers working on (not with) Googlyscript.
# Turn on -w with unicorn once in a while.  Haml/sass is too chatty to leave this on.

require File.join(File.dirname(__FILE__), 'lib', 'googlyscript.rb')
require 'sass/plugin'

Sass::Plugin.options[:template_location] = File.join(Googly.base_path, 'src', 'stylesheet')
Sass::Plugin.options[:css_location] = File.join(Googly.base_path, 'public', 'stylesheets')
Sass::Plugin.options[:cache_location] = File.join(Googly.base_path, 'tmp')

Googly.script '/goog', :goog
Googly.script '/goog_vendor', :goog_vendor
Googly.script '/googly', :googly
Googly.config.haml[:format] = :html5

# use Rack::CommonLogger # slow, adds ~20% to goog.editor Demo page load
use Rack::Reloader, 1
use Rack::Lint
use Rack::ShowExceptions
use Googly::Sass
use Googly::Middleware, File.join(Googly.base_path, 'public', 'index.html')

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

run Rack::File.new File.join(Googly.base_path, 'public')

print "Scripting engaged.  Caution: Googlies bond instantly to skin.\n"
