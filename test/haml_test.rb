require 'test_helper'

class HamlTest < Test::Unit::TestCase

  def setup
    @options = {:dir => File.expand_path(File.join(File.dirname(__FILE__), '..', 'public'))}
  end


  def test_serve_files
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Haml.new(@options))).
      get("/test_haml.html")
    assert res.ok?
    assert res =~ /<html>/
  end

  def test_forbidden_response
    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Haml.new(@options))).
      get("/../test_haml.html")
    assert !res.ok?
    assert res.status == 403
  end
end
