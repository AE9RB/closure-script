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

Note that Sass::Plugin::Rack and Rack::CommonLogger are not performant with
the large number of get requests that Google Closure can create.
Use Googly::Sass instead of Sass::Plugin::Rack and make sure you use -E none for rackup.