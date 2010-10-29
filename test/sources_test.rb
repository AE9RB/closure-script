require 'test_helper'

class SourcesTest < Test::Unit::TestCase

  BIG_NAMESPACE = "goog.editor.Field"
  CLOSURE_LIBRARY = File.join(Googly.base_path, 'closure-library')
  CLOSUREBUILDER = File.join(CLOSURE_LIBRARY, 'closure', 'bin', 'build', 'closurebuilder.py')
  CALCDEPS = File.join(CLOSURE_LIBRARY, 'closure', 'bin', 'calcdeps.py')
  FIELD_JS = File.join(CLOSURE_LIBRARY, 'closure', 'goog', 'editor', 'field.js')
  GOOG_SOURCE = Googly::Source.new([['/goog', {:dir => CLOSURE_LIBRARY, :source => true}]])

  def test_files_against_closurebuilder
    closurebuilder_files = `#{CLOSUREBUILDER} --root=#{CLOSURE_LIBRARY.dump} -n #{BIG_NAMESPACE.dump} 2>/dev/null`
    closurebuilder_files = closurebuilder_files.split
    compiler_files = GOOG_SOURCE.files(BIG_NAMESPACE)
    assert_equal closurebuilder_files.length, compiler_files.length
    # Closurebuilder.py uses sets instead of arrays so dependency order can't be verified.
    assert_equal closurebuilder_files.sort, compiler_files.sort
  end

  def test_files_against_calcdeps
    calcdeps_files = `#{CALCDEPS} --path=#{CLOSURE_LIBRARY.dump} -i #{FIELD_JS.dump} 2>/dev/null`
    calcdeps_files = calcdeps_files.split
    compiler_files = GOOG_SOURCE.files(BIG_NAMESPACE)
    assert_equal calcdeps_files.length, compiler_files.length
    # Calcdeps generates the same ordering we do.  Yay!
    assert_equal calcdeps_files, compiler_files
  end
  
end
