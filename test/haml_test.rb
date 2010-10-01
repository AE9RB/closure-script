require 'test_helper'

class HamlTest < Test::Unit::TestCase


  def test_serve_files
    options = {:dir => File.expand_path(File.join(File.dirname(__FILE__), '..', 'public'))}

    res = Rack::MockRequest.new(Rack::Lint.new(Googly::Haml.new(options))).
      get("/test_haml.html")
    assert res.ok?
    assert res =~ /<html>/
  end
end

