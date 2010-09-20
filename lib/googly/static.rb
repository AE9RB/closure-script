require 'time'
require 'rack/utils'
require 'rack/file'

class Googly

  class Static < Rack::File
    
    def initialize(path, options)
      @root = options[:dir]
    end    
    
    def not_found
      body = "File not found\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
    
  end
  
end