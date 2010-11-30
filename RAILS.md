## Rails 3

Gemfile:

    group :development do
      gem 'googlyscript'
    end

config/environments/development.rb:

    config.middleware.insert_before ActionDispatch::Static, Googly::Middleware
    Googly.script '/goog', :goog
    Googly.script '/myapp', 'app/javascripts'

Restart the server and test: `http://localhost:3000/goog/demos/index`

## Rails 2

app/metal/jsdev.rb:

    require 'googlyscript'
    begin
      Googly.script '/goog', :goog 
    rescue Exception => e
    end

    class Jsdev

      @@server ||= Googly::Server.new(Googly.sources)
  
      def self.call(env)
        if RAILS_ENV == 'development'
          @@server.call env
        else
          [404, {}, []]
        end
      end

    end
    
Restart the server and test: `http://localhost:3000/goog/demos/index`

## Sass

Sass should be installed into your Rails app normally.  However, be aware
that the Plugin will only create .css files when a Rails controller is accessed.
If you want Sass to create .css files when accessing just Googlyscript files,
you can add this middleware:

    config.middleware.use Googly::Sass

Do not use Sass::Plugin::Rack.  It will slow everything down substantially.
