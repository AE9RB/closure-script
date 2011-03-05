require 'test_helper'

# Python is required as a dependency of calcdeps.py and closurebuilder.py

class SourcesTest < MiniTest::Unit::TestCase

  CLOSURE_LIBRARY = File.join(Closure.base_path, 'scripts', 'closure-library')

  NAMESPACES = ["goog.editor.Field", "goog.ds.JsonDataSource"]
  FIELD_JS = File.join(CLOSURE_LIBRARY, 'closure', 'goog', 'editor', 'field.js')
  JSONDATASOURCE_JS = File.join(CLOSURE_LIBRARY, 'closure', 'goog', 'datasource', 'jsondatasource.js')

  CLOSUREBUILDER = File.join(CLOSURE_LIBRARY, 'closure', 'bin', 'build', 'closurebuilder.py')
  CALCDEPS = File.join(CLOSURE_LIBRARY, 'closure', 'bin', 'calcdeps.py')

  FILES = []
  sources = Closure::Sources.new
  sources.add CLOSURE_LIBRARY
  begin
    sources.files_for(NAMESPACES[0], FILES)
    sources.files_for(NAMESPACES[1], FILES)
  rescue Closure::Sources::BaseJsNotFoundError
    raise "ERROR: it looks like closure-library isn't downloaded yet"
  end

  def test_files_against_closurebuilder
    closurebuilder_files = `#{CLOSUREBUILDER} --root=#{CLOSURE_LIBRARY.dump} -n #{NAMESPACES[0].dump} -n #{NAMESPACES[1].dump} 2>/dev/null`
    closurebuilder_files = closurebuilder_files.split
    assert_equal closurebuilder_files.length, FILES.length
    # Closurebuilder.py uses sets instead of arrays so dependency order can't be verified.
    assert_equal closurebuilder_files.sort, FILES.sort
  end

  def test_files_against_calcdeps
    # Calcdeps claims to support `-i ns:goog.editor.Field` syntax but it fails.
    # The stack trace shows the code path taken doesn't actually work.
    # We can run this with explicit filenames.
    calcdeps_files = `#{CALCDEPS} --path=#{CLOSURE_LIBRARY.dump} -i #{FIELD_JS.dump} -i #{JSONDATASOURCE_JS.dump} 2>/dev/null`
    calcdeps_files = calcdeps_files.split
    assert_equal calcdeps_files.length, FILES.length
    # Calcdeps generates the same ordering we do.  Yay!
    assert_equal calcdeps_files, FILES
  end
  
end
