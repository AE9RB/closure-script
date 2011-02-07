Closure Script for Google Closure Compiler, Library, and Templates.

Licensed under the Apache License, Version 2.0 (the "License"); 
<http://www.apache.org/licenses/LICENSE-2.0>

Project home;
<http://www.closure-script.com/>

Getting Started documentation is on the wiki;
<https://github.com/dturnbull/closure-script/wiki>

Advanced documentation is in YARD format;
<http://rubydoc.info/gems/closure/frames>


Version 1.1

 * New gem name: gem install closure
 * The official project name is now Closure Script.  The development codename, Googlyscript, is retired.
 * Interfaces to Closure::Sources has been cleaned for use in a non-server environment.  No more placeholder arguments and sources can be added without an http route.
 * Experimental support for provide/require in externs.  Scripts with a .externs suffix are scanned for goog.provide and goog.require statements.  Due to compiler.jar not supporting this yet, place start and end comment markers on the lines before and after the goog statements.
 * Closure Templates error reporting has been integrated.  If you were checking Soy errors you no longer need to if you are loading goog.deps_js or using goog.compile(args).to_response_with_console.

Version 1.0

 * Credits: David Turnbull, Dan Herrera, Max Ogden and Andrew Kurtz.