Closure Script for Google Closure Compiler, Library, and Templates.

Licensed under the Apache License, Version 2.0 (the "License"); 
<http://www.apache.org/licenses/LICENSE-2.0>

Project blog;
<http://www.closure-script.com/>

Getting Started documentation is on the wiki;
<https://github.com/dturnbull/closure-script/wiki>

Advanced documentation is in YARD format;
<http://rubydoc.info/gems/closure/frames>


 * New gem name: gem install closure
 * New project name: Closure Script
 * ::Closure namespace is used with sub-namespaces Closure::Compiler Closure::Templates and Closure::Script.
 * Experimental support for provide/require in externs.  Scripts with a .externs suffix are scanned for goog.provide and goog.require statements.  Due to compiler.jar not supporting this yet, place start and end comment markers on the lines before and after the goog statements.
 * Closure Templates error reporting has been integrated.  If you were checking Soy errors you no longer need to if you are loading goog.deps_js or using goog.compile(args).to_response_with_console.
