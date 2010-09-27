require 'test_helper'

class CompilerTest < Test::Unit::TestCase

  CLOSUREBUILDER = File.join(Googly.base_path, 'closure-library', 'closure', 'bin', 'build', 'closurebuilder.py')
  CLOSURE_LIBRARY = File.join(Googly.base_path, 'closure-library')
  GOOG_SOURCE = Googly::Source.new([['/goog', {:dir => CLOSURE_LIBRARY, :deps => true}]])

  def test_file_list
    namespace = "goog.editor.Field"
    closurebuilder_files = `#{CLOSUREBUILDER} --root=#{CLOSURE_LIBRARY.dump} -n #{namespace} 2>/dev/null`
    closurebuilder_files = closurebuilder_files.split
    compiler = Googly::Compiler.new(GOOG_SOURCE, Googly::BeanShell.new, Googly.config)
    compiler_files = compiler.files(namespace)
    assert_equal closurebuilder_files.length, compiler_files.length
    # Unfortunately, closurebuilder.py uses sets instead of arrays
    # so the dependency order can't be verified.
    # Changing source.py to use array+append instead of set+add
    # will allow the following test to pass without sort.
    assert_equal closurebuilder_files.sort, compiler_files.sort
  end
  
end

