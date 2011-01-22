Licensed under the Apache License, Version 2.0 (the "License"); 
<http://www.apache.org/licenses/LICENSE-2.0>

Getting Started documentation is on the wiki:
<https://github.com/dturnbull/googlyscript/wiki>

Advanced documentation is in YARD format:
<http://rubydoc.info/gems/googlyscript/frames>

Googlyscript - An experience with Google Closure.

* Server-side templates free you from the browser security model.  ERB and Haml or add your own.
* Every Google Closure compiler.jar option is supported.
* Every SoyToJsSrcCompiler.jar option is supported.
* Easy to install rack middleware.  Works in frameworks or stand-alone.
* No config files to manage or command line tools to learn.  Complexity removed, not added.
* On-the-fly deps.js generation with source change detection.  Never think about this again.
* Compilers check File.mtime and won't run if you haven't modified source.
* Completely replaces python tools and plovr.
* Thread-safe.  Can handle over a thousand requests per second on a single Mongrel.
* Performance-tuned http caching that won't manifest stale pages in development.
* Java REPL so you only pay the Java startup cost once.
