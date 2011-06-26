# By putting the require inside the block, we allow for a generous
# selection of engines without needing to actually install all of them.

# ERB
Closure.config.engines['.erb'] = Proc.new do |script, locals|
  require 'erb'
  erb = ::ERB.new(File.read(script.render_stack.last), nil, '-')
  erb.filename = script.render_stack.last
  script.extend ::ERB::Util
  script_binding = script.instance_eval{binding}
  script.send(:instance_variable_set, '@_closure_locals', locals)
  set_locals = locals.keys.map { |k| "#{k}=@_closure_locals[#{k.inspect}];" }.join
  eval set_locals, script_binding
  erb.result script_binding
end

# HAML
Closure.config.haml = {:format => :html5}
Closure.config.engines['.haml'] = Proc.new do |script, locals|
  require 'haml'
  options = Closure.config.haml.merge(:filename => script.render_stack.last)
  ::Haml::Engine.new(File.read(script.render_stack.last), options).render(script, locals)
end

# MARKDOWN
Closure.config.kramdown = {:input => 'Markdown'}
kramdown = Proc.new do |script, locals|
  require 'kramdown'
  html = ::Kramdown::Document.new(File.read(script.render_stack.last), Closure.config.kramdown).to_html
  if script.render_stack.size == 1
    <<-EOT
<!DOCTYPE html>
<html><head>
<meta name="generator" content="kramdown #{::Kramdown::VERSION}" />
<style type="text/css" media="screen">
  body{font:13px/1.231 arial,helvetica,clean,sans-serif;*font-size:small;*font:x-small;}
  select,input,button,textarea,button{font:99% arial,helvetica,clean,sans-serif;}
  table{font-size:inherit;font:100%;}
  pre,code,kbd,samp,tt{font-family:monospace;*font-size:108%;line-height:100%;}
  pre{padding:5px 12px;margin-top:4px;border:1px solid #eef;background:#f5f5ff;}
</style></head><body>
#{html}
</body></html>
    EOT
  else
    html
  end
end
Closure.config.engines['.md'] = kramdown
Closure.config.engines['.markdown'] = kramdown
