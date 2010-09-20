require 'test_helper'

class StaticTest < Test::Unit::TestCase
  File.expand_path(File.dirname(__FILE__))

  PUBLIC = ['', {:dir => File.expand_path(File.join(File.dirname(__FILE__), '..', 'public'))}]
  

  def test_serve_files
    # Basic sanity; ensure we are serving files after inheriting Rack::File
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Static.new(*PUBLIC))).
      get("/test.html")
    assert res.ok?
    assert res =~ /<body>/
  end
  
  def test_404_error
    # Googly static file server uses custom 404 error
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Static.new(*PUBLIC))).
      get("/file_not_exist")
    assert res.not_found?
    assert_equal "File not found\n", res.body
  end
  
end

