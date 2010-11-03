require 'test_helper'
require 'haml'

class HamlTest < Test::Unit::TestCase

  def setup
    @options = File.join(Googly.base_path, 'test')
  end

  def test_serve_from_single_file_extension
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Route.new(@options))).
      get("/haml_test_1.html")
    assert res.ok?
    assert res =~ /<html>/
  end

  def test_serve_from_single_file_extension_with_no_extension
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Route.new(@options))).
      get("/haml_test_1")
    assert res.ok?
    assert res =~ /<html>/
  end

  def test_serve_from_double_file_extension
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Route.new(@options))).
      get("/haml_test_2.html")
    assert res.ok?
    assert res =~ /<html>/
  end

  def test_serve_from_double_file_extension_with_no_extension
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Route.new(@options))).
      get("/haml_test_2")
    assert res.ok?
    assert res =~ /<html>/
  end

  def test_forbidden_response
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Route.new(@options))).
      get("/../test.html")
    assert !res.ok?
    assert res.status == 403
  end
end
