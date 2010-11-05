require 'test_helper'

class RouteTest < Test::Unit::TestCase

  def setup
    root = File.join(Googly.base_path, 'test', 'fixtures')
    route = Rack::Lint.new(Googly::Route.new(root))
    @request = Rack::MockRequest.new(route)
  end

  def test_file_not_found
    assert @request.get("/nOT/Real.fILE").not_found?
  end

  def test_bare_template_extension
    # Bare templates such as haml_test.erb are treated as html
    response = @request.get("/haml_test.html")
    assert response.ok?
    assert_equal 'text/html', response.content_type
  end
  
  def test_html_extensions
    assert @request.get("/html_test").ok?
    assert @request.get("/html_test.html").ok?
    assert @request.get("/html_test.html.html").not_found?
  end
  
  def test_template_no_extension
    assert @request.get("/erb_test").ok?
    assert @request.get("/haml_test").ok?
  end
  
  def test_non_html_template_extension
    # The file proper comes back as text/plain
    response = @request.get("/erb_test.js.erb")
    assert response.ok?
    assert_equal 'text/plain', response.content_type
    # The renedered version is application/javascript
    response = @request.get("/erb_test.js")
    assert response.ok?
    assert_equal 'application/javascript', response.content_type
  end
  
  def test_html
    response = @request.get("/html_test.html")
    assert response.ok?
    assert_equal 'text/html', response.content_type
    assert response =~ /PASS/
  end
  
  def test_erb
    response = @request.get("/erb_test.html")
    assert response.ok?
    assert_equal 'text/html', response.content_type
    assert response =~ /PASS/
  end

  def test_haml
    response = @request.get("/haml_test.html")
    assert response.ok?
    assert_equal 'text/html', response.content_type
    assert response =~ /PASS/
  end
  

end
