require 'test/unit'
require 'rubygems'
require 'rack/mock'

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'googly'))

# Run all tests if someone executes this script directly
if $0 == __FILE__
  Dir.glob('**/*_test.rb').each {|f| require f}
end