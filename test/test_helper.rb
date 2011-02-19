require 'test/unit'
require 'rubygems'
require 'rack/mock'

closure_lib_path = File.expand_path('../lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(closure_lib_path) if !$LOAD_PATH.include?(closure_lib_path)
require 'closure'

# Run all tests if someone executes this script directly
if $0 == __FILE__
  Dir.glob('*_test.rb').each {|f| require f}
end
