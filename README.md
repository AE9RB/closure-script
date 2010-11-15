Licensed under the Apache License, Version 2.0 (the "License"); 
http://www.apache.org/licenses/LICENSE-2.0

Step 1:  Install the gem.
> `gem install googlyscript`

Step 2: Copy the files from here to your work space:
> `http://github.com/dturnbull/googlyscript/tree/master/generators/stand_alone/`

Step 3: Run the server from where config.ru is.
> `rackup`

Step 4: View the demos.
> `http://localhost:9009/goog/demos/index.html`

* Easy to configure rack middleware
* Works in frameworks or stand-alone.  Only dependency is Ruby and Rack.
* Multithreaded-safe with a high-performance caching strategy.
* Automatic on-the-fly deps.js generation with source change detection.
* Compiler checks File.mtime and won't run if you haven't modified source.
* Every Google Closure compiler option is supported.
* Java REPL so you only pay the Java startup cost once.
* Server-side templates.  ERB and Haml or add your own.
* Sass-compatible.  Use Googly::Sass not Sass::Plugin::Rack.
* Soy (coming soon)
