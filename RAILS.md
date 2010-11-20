## Rails 3

Gemfile:

    group :development do
      gem 'googlyscript'
    end

config/environments/development.rb:

    config.middleware.use Googly::Middleware
    Googly.script '/goog', :goog
    Googly.script '/myapp', 'app/javascripts'

Restart the server and test: `http://localhost:3000/goog/demos/index`

## Rails 2

config/environments/development.rb:

    config.gem 'googlyscript'
    config.middleware.use Googly::Middleware
    Googly.script '/goog', :goog
    Googly.script '/myapp', 'app/javascripts'
    
Restart the server and test: `http://localhost:3000/goog/demos/index`

## Sass

Sass should be installed into your Rails app normally.  However, be aware
that the Plugin will only create .css files when a Rails controller is accessed.
If you want Sass to create .css files when accessing just Googlyscript files,
you can add this middleware:

    config.middleware.use Googly::Sass

Do not use Sass::Plugin::Rack.  It will slow everything down substantially.
