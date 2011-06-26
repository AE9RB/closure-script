# Closure Script Overview

Closure Script is a specialized web server that automates the Closure build process.
Typically, Closure development is driven by static HTML pages or your main
application is given knowledge of your development systems.
With Script, you build HTML or Javascript with embedded Ruby.
The core Script technology is very simple and all Scripts execute in the same context
regardless if they are test, demo, or compiler scripts.

Exploring or extending the examples is the best way to learn <a href="https://github.com/dturnbull/closure-script">Closure Script</a>.  If you
are looking for information about Closure in general, 
<a href="http://oreilly.com/catalog/0636920001416">Closure: The Definitive Guide</a>
is a solid reference.

## Closure::Script Context

A Script is executed in the context of a Rack::Request that has been extended
with Closure::Script.  Rack::Request is everything having to do
with the http request and Closure::Script is all about the interface to Closure.
In most cases, the only Script I will put on a page simply relays the query string
to the compiler Script:

    <script src='compiler.js?<%= query_string %>'></script>

Script helps with testing because it can see your filesystem in ways that
browsers are not allowed to.
Here's a replacement for the static alltests.js in closure-library:

    <% all_test_files = Dir.glob expand_path '**/*_test.html'
       json_strings = all_test_files.map { |x| relative_src(x).dump }
    -%>var _allTests = [<%= json_strings.join(',') %>];

A Script can be entirely Ruby, entirely HTML, or anything in-between.  Scripts of
mostly Ruby look like models or controllers and Scripts of mostly HTML look like
views.  This makes Script a poor framework for enforcing web server patterns but
gives it a great deal of flexibility as a build tool.

The instance of Closure::Goog in Closure::Script provides easy access to the compiler and other information
about your source Javascript.  Script that compiles generally starts simple then grows with options
as your project matures.  Here's the simple version:

    <% @response = goog.compile(%w{
      --compilation_level ADVANCED_OPTIMIZATIONS
      --js_output_file compiler_out.js
      --ns myapp.hello
    }).to_response %>

And what it looks likes when you start processing query options:

    <% args = %w{
      --ns myapp.hello
    }
    args += case query_string
    when 'build': %w{
      --compilation_level ADVANCED_OPTIMIZATIONS
      --js_output_file compiler_build.js
    }
    when 'debug': %w{
      --debug true
      --formatting PRETTY_PRINT
      --compilation_level ADVANCED_OPTIMIZATIONS
      --js_output_file compiler_debug.js
    }
    else;[];end
    @response = goog.compile(args).to_response %>

The @response attribute of Closure::Script is an instance of Rack::Response.  If you do
nothing with this then then results of rendering will be sent as a response.  If you
write to @response or change it to another object then the rendering is discarded.

Regardless of your language background, cut-and-paste programming from the
scaffold examples should be practical.  That's the idea anyways.
If you can conditionally build arrays of strings in Ruby, you're good to go. 
But, of course, the more Ruby you know the more you'll be able to do.

## config.ru

This file is unique in that there's only one and it's the only one that isn't a Script.
Ruby developers may recognize the filename since it's convention for starting a web server.
Changing this file requires a server restart but there isn't much in config.ru that needs changing.

The default config.ru explains more in its comments.  The smallest practical config.ru would be:

    require 'closure'
    Closure.add_source '.', '/'
    use Closure::Middleware
    run Rack::File.new '.'
    
## Argument Augmentation

Closure Script adds additional features to the compiler like file modification checks and
easy module generation.  It does this by augmenting the command line arguments.  
The compiler arguments in Ruby are going to be the same arguments as if you ran compiler.jar
from the command line.  Except for the few things that are augmented by Closure Script.

The most important augmentation is the addition of the --ns option.  This is how you
compile a namespace and its dependencies.  How it works is simple in concept.
Closure Script watches your source files and knows all their goog.provide and require
namespaces.  It will drop the --ns option and replace it with --js options to
satisfy the namespace before calling compiler.jar.

If you're coming from plovr then you are probably used to compiling a namespace by
specifying a file as the root.  Closure Script will not calculate the dependencies if
you use --js.  This works for plovr with its JSON config, but overloading --js in Script
would leave ambiguity that could never be resolved.  Do I follow the namespaces or not?

The are three more augmented arguments.  Not specifying a --compilation_level will
load the original sources instead of compiling.  Module format --module api:*:app will
have the * replaced with an actual file count.  And, if you specify a --js_output_file
then compilation will be conditional on one of the sources having a modification time
greater than the output file.

Because Script doesn't use a modified compiler, you are free to use the latest
compiler version or revert to an older one.  Simply set Closure.config.compiler_jar
in config.ru to point to the one you want to use.  Java and JRuby developers: the
jars are fetched with URLClassLoader and don't need to be in any Java paths.

## Compatibility

The .jar only needs Java.  It contains JRuby and the Closure tools.  Guaranteed success.

The gem should work on any kind of Ruby that is like version 1.8 or greater.
The Script source code is non-magical so any issues will be easy to fix.
Mac, Linux, and Windows all work.  If you can get Rack running, Closure
Script should be no problem.

## Script Engines

Closure Script comes with support for several file formats.
If you want something else, it is easy to add new engines to Script
with the Closure.config.engines setting.

ERB (.erb)
: This is plain old HTML with support for Ruby in <% %> and <%= %> tags.
  ERB::Util is mixed in for <%=h 'string' %> and <%=u 'string' %> helpers.

Haml (.haml)
: This is an indented format (no closing tags) that a lot of Ruby developers use.

Markdown (.md, .markdown)
: Read-me files and developer documentation look nice for cheap and easy.
  This very document is in markdown source.