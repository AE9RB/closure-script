class Googly

  class Deps
    
    def initialize(path, options)
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