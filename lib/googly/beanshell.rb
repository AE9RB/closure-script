class Googly
  
  # Googly will manage a single BeanShell to run the Java tools.
  # This way we don't pay the Java startup costs on every compile job.

  class BeanShell
    
    PROMPT = /^bsh % $\Z/
    
    # Shortcut to Googly.compile_js in Googly.jar.
    def compile_js(args)
      run "Googly.compile_js(new String[]{#{args.collect{|a|a.dump}.join(', ')}});"
    end
    
    # Public function to run any Java command.
    # Handles error when the Java process is killed.
    def run(command)
      begin
        return execute command
      rescue Errno::EPIPE
        # Shut down broken pipe; another will be started.
        @shell.close
        @shell = nil
      end
      # This "second chance" will not rescue the error.
      puts "Java BeanShell is restarting (this should not happen)"
      execute command
    end
    
    protected
    
    # Executes a command on the REPL and returns the result.
    def execute(command)
      shell << command unless command == :init
      result = ''
      result << shell.readpartial(8192) until result =~ PROMPT
      result.sub PROMPT, ''
    end

    # Builds an IO to a Googly Java REPL.
    def shell
      return @shell if @shell
      classpath = [Googly.config.compiler_jar]
      classpath << File.join(Googly.base_path, 'beanshell', 'bsh-2.0b4.jar')
      classpath << File.join(Googly.base_path, 'beanshell', 'Googly.jar')
      @shell = IO.popen("#{Googly.config.java} -classpath #{classpath.join(':')} bsh.Interpreter", 'r+')
      execute :init
      @shell
    end
    
  end
  
end