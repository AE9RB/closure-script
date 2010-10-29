class Googly

  # @todo This is a work in progress.

  class Erb
    
    def initialize(options)
    end
    
    def call(env)
      body = "File not found\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
    
  end
  
end