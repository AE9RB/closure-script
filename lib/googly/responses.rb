class Googly
  
  # Standard rack responses shared amongst everything Googly.
  
  module Responses
    
    # Status 403 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def forbidden
      body = "Forbidden\n"
      [403, {"Content-Type" => "text/plain",
             "Content-Length" => body.size.to_s,
             "X-Cascade" => "pass"},
       [body]]
    end

    # Status 404 with X-Cascade => pass.
    # @return (Array)[status, headers, body]
    def not_found
      body = "File not found\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s,
         "X-Cascade" => "pass"},
       [body]]
    end
        
  end
end