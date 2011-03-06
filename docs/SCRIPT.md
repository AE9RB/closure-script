# Closure Script Overview

Closure Script is a specialized web server that automates the Closure build process.
Typically, Closure development is driven by static HTML pages or your main
application is given knowledge of your development systems.
With Script, you build HTML or Javascript with embedded Ruby.
The core Script technology is very simple and all Scripts execute in the same context
regardless if they are test, demo, or compiler scripts.

Extending one of the scaffolds is the best way to learn Closure Script.
The explanations and examples here are meant as a overview of how Closure
Script pulls everything together.

## Closure::Script Context

In most cases, the only Script I will put on a page simply relays the query string
to the compiler script:

    <script src='compiler.js?<%= query_string %>'></script>
    
Here's how you might respond to an XmlHttpRequest with fixtures from the filesystem:

    if xhr?
      @response.headers["Content-Type"] = 'text/plain'
      @response.write File.read 'file.txt'
    end

The methods 'query_string' and 'xhr?' both come from Rack::Request.  A Script is executed in the context
of a Rack::Request that has been extended with Closure::Script.  Rack::Request is everything having to do
with the http request and Closure::Script is all about the interface to Closure.

The @response attribute of Closure::Script is an instance of Rack::Response.  If you do nothing with
this then then results of rendering will be sent as a response.  If you write to
@response or change it to another object then the rendering is discarded.

A Script can be entirely Ruby, entirely HTML, or anything in-between.  Scripts of mostly Ruby
look like controllers and scripts of mostly HTML look like views.  This makes Script a poor framework
for enforcing web server patterns but gives it a great deal of flexibility as a build tool.

The goog instance in Closure::Script provides easy access to the compiler and other information
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


You don't really need to learn Ruby to use Closure Script.  Regardless of your language
background, cut-and-paste programming from the scaffold examples should be practical.
That's the idea anyways.  Writing complex Scripts like svn.erb is not necessary to be successful.
But, of course, the more Ruby you know the more you'll be able to do with Script.

## config.ru

This file is unique in that there's only one and it's the only one that isn't a Script.
Ruby developers may recognize the filename since it's convention for starting a Ruby web server.
Changing this file requires a server restart but there isn't
much in config.ru that needs changing.

The example config.ru explains more in its comments.  The smallest working config.ru would be:

    require 'closure'
    Closure.add_source '.', '/'
    use Closure::Middleware
    run Rack::File.new '.'
    
## Argument Augmentation

Closure Script adds additional features to the compiler like file modification checks and
easy module generation.  It does this by augmenting the command line arguments.  
The compiler arguments in Ruby are going to be the
same as the arguments if you ran compiler.jar from the command line.  Except for the
few things that are augmented by Closure Script.

The most important augmentation is the addition of the --ns option.  This is how you
compile a namespace and its dependencies.  How it works is simple to explain.
Closure Script watches your source files and knows all their goog.provide and require
namespaces.  It will drop the --ns option and replace it with --js options to
satisfy the namespace before calling compiler.jar.

If you're coming from plovr then you are probably used to compiling a namespace by
specifying a file as the root.  Closure Script will not calculate the dependencies if
you use --js.  This works for plovr with its JSON config, but overloading --js in Script
would leave ambiguity that could never be resolved.  Do I follow the namespaces or not?

The are three more augmented arguments.  Not specifying a --compilation_level will
load the original sources instead of compiling.  The * in --module api:*:app will
be replaced with an actual file count.  If you specify a --js_output_file then
compilation will be conditional on one of the sources having a modification time
greater than the output file.

The scaffold examples demonstrate all augmentations.
