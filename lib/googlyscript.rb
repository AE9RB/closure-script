googly_lib_path = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(googly_lib_path) if !$LOAD_PATH.include?(googly_lib_path)
require 'googly'
