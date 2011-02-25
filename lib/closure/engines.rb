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
#TODO kramdown for .md and .markdown
