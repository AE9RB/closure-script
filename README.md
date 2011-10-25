# Closure Script

A development environment for Google Closure Tools.

Licensed under the Apache License, Version 2.0 (the "License"); 
<http://www.apache.org/licenses/LICENSE-2.0>

# Installing

Everything you need for advanced Google Closure development is available in a
single .jar for the Java Virtual Machine.  You may also run the tools on any
Ruby platform (>=1.8.6) including JRuby (JVM), Rubinius (LLVM), and Ruby 1.9 (YARV).

It is generally easier to get started with the .jar distribution, especially
under Windows.  Mac OSX and most Linux will have a compatible Ruby by default.

## Java (.jar)

### Step 1: Download to a new folder

    cd ~/empty-dir
    curl -LO https://github.com/downloads/dturnbull/closure-script/closure-1.4.2.jar

### Step 2: Start server from the new folder

    java -jar closure-1.4.2.jar

### Step 3: Open a web browser

    http://localhost:8080/ 


## Ruby (.gem)

### Step 1: Install the gem

    gem install closure

### Step 2: Start server from a new folder

    cd ~/empty-dir
    closure-script
    
### Step 3: Open a web browser

    http://localhost:8080/


# The Closure Script Method

When you start the server for the first time in an empty folder, the home page
will prompt you to install scaffolding.  This includes three example projects to 
demonstrate soy, modules, and unobtrusive markup.  Dissecting and working with
these examples is the fast track to understanding The Closure Script Method.

## The Server

Closure Script is a high-performance, multi-threaded web application engineered 
exclusively for the needs of Google Closure Javascript development.

You will be freed from the command line.  All error output from the compiler
will show on the Javascript console.  This avoids lost time from not being
in the correct log and missing an important error.  Javascript compilation
is done just-in-time and only when source files have changed.
No need for a separate build step; just refresh the browser.  Not working?
Check your Javascript console.  Then back to your editor.

## Easy Configuration

You'll need to supply the directories where you have source Javascript and static files.
Ruby developers will recognize that Closure Script is Rack middleware.  This makes it trivial
to include the Closure Script build tool in a Rails application.  If you're not developing a
Ruby application, your ```config.ru``` will probably never be more complex than the following:

    require 'closure'
    Closure.add_source '.', '/'
    use Closure::Middleware, 'index'
    run Rack::File.new '.'
    
The add_source command may be duplicated for each source Javascript folder you want to
serve.  The first argument is the local filesystem path, the second is the mount point
for the http server.  Make sure not to accidentally serve more than one copy of
Closure Library per Closure Script server or you'll get an error.

## Cut-and-Paste Ruby

In practice, all you do with Ruby is adjust the arguments to compiler.jar by
analyzing options on the URL query string.  If you can handle conditionally appending
strings to an array in Ruby, then you're fully qualified to use Closure Script!
There's enough example code in the scaffolding to cut-and-paste your way to victory.

### Demo Scripts

The Closure Script Method is to create various demo pages to drive development.  You may
also choose to use your main application instead of Closure Script for your demo pages.

Files ending with .erb are Closure Scripts and will have their embedded Ruby evaluated
as they are served.  Scripts may also render other Scripts and pass variables if you
need that complexity.  Scripts default to a MIME type of text/html so ```demo.erb``` is
the same as ```demo.html.erb```.

    <html>
      <head>
        <script src='compiler.js?<%= query_string %>'></script>
      </head>

### Compiler Scripts

Compilation is performed by requesting a file that generates Javascript instead of HTML.
The goog.compile() function of Closure Script handles everything for you.

Note that goog.compile() does not simply call the compiler.  It will monitor your source
files and skip calling the compiler if everything is up to date.  The Java process will
remain running on a REPL so subsequent compilations don't pay the Java startup cost.
The dependency tree for all your sources is known so you can build from namespaces
(--ns) as well as files (--js).  Modules have been automated to find common dependencies,
like plovr, and work from namespaces so you don't need to use filenames and counts.
The luxurious goog.compile() can serve up a loader for the raw, uncompiled files,
even when working with modules.

A very simple compiler.js.erb is as follows.  Check the scaffold for practical examples
that use the query string.

    <%
    args = %w{
      --compilation_level  ADVANCED_OPTIMIZATIONS
      --js_output_file     compiler_build.js
      --ns                 myapp.helloWorld
    }
    @response = goog.compile(args).to_response
    %>

### Testing

Closure Script helps with testing because it can see your data in ways that
browsers are not allowed to. The ```alltests.js``` file in Closure Library is
generated by a program that scans the filesystem.  Here's a replacement in
Closure Script so that a manual build step never has to be executed again:

    <% all_test_files = Dir.glob expand_path '**/*_test.html'
       json_strings = all_test_files.map { |x| relative_src(x).dump }
    -%>var _allTests = [<%= json_strings.join(',') %>];
    
Since all of Ruby is at your disposal, you could even pull fixture data from SQL
or a web service.  Perhaps a fixture refresh happens when the developer pushes a
form button.  The svn.erb tool is a complex example that uses threads and a
background process.  You're only limited by your imagination.
