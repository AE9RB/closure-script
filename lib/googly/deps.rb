class Googly

  class Deps
    
    BASE_REGEX_STRING = '^\s*goog\.%s\(\s*[\'"](.+)[\'"]\s*\)'
    PROVIDE_REGEX = Regexp.new(BASE_REGEX_STRING % 'provide')
    REQUIRE_REGEX = Regexp.new(BASE_REGEX_STRING % 'require')
    
    def initialize(routes)
      @routes = routes
    end
    
    def call(env)
      if Rack::Utils.unescape(env["PATH_INFO"]) == '/deps.js'
        deps
      else
        not_found
      end
    end
    
    def deps
      added_files = []
      changed_files = []
      deleted_files = []
      # Set up deps and mark everything for deletion
      @deps ||= {}
      @deps.each {|f, dep| dep[:deleted] = true}
      # Scan for changes
      @routes.collect do |path, options|
        next unless options[:deps]
        dir = options[:dir]
        dir_range = (dir.length..-1)
        Dir.glob(File.join(dir,'**','**.js')).each do |filename|
          dep = (@deps[filename] ||= {})
          dep.delete(:deleted)
          mtime = File.mtime(filename)
          if dep[:mtime] != mtime
            if dep == {}
              added_files << filename
            else
              changed_files << filename
            end
            @deps_js = nil
            raise 'deps internal error' unless filename.index(dir) == 0
            file = File.read filename
            dep[:path] = "#{path}#{filename.slice(dir_range)}"
            dep[:provide] = file.scan(PROVIDE_REGEX).flatten.sort
            dep[:require] = file.scan(REQUIRE_REGEX).flatten.sort
            dep[:mtime] = mtime
          end
        end
      end
      # Delete not-found files
      @deps.select{|f, dep| dep[:deleted]}.each do |filename, options|
        @deps_js = nil
        deleted_files << filename
        @deps.delete(filename)
      end
      # Build new deps.js as needed
      unless false and @deps_js
        @deps_js = []
        @deps_js << "// This deps.js was generated on-the-fly by Googlyscript\n"
        @deps_js << "goog.basePath = '';\n"
        @deps.dup.sort{|a,b|a[1][:path]<=>b[1][:path]}.each do |filename, dep|
          @deps_js << "goog.addDependency(#{dep[:path].inspect}, #{dep[:provide].inspect}, #{dep[:require].inspect});\n"
        end
        @deps_content_length = @deps_js.inject(0){|sum, s| sum + s.length }.to_s
        # Log after rebuilding
        puts "::Googly::Deps: #{added_files.length} added, #{changed_files.length} changed, #{deleted_files.length} deleted."
      end
      # Respond
      [200, {"Content-Type" => "text/javascript",
         "Content-Length" => @deps_content_length},
        @deps_js]
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