class Googly
  
  # Googly will manage a single BeanShell to run the Java tools.
  # This way we don't pay the Java startup costs on every compile job.

  class BeanShell
    
    PROMPT = /^bsh % $\Z/
    
    def compile_js(args)
      run "Googly.compile_js(new String[]{#{args.collect{|a|a.dump}.join(', ')}});"
    end
    
    def run(command)
      shell << command
      read_until_prompt
    end
    
    private

    def read_until_prompt
      result = ''
      until result =~ PROMPT
        read = shell.readpartial(8192)
        result << read
      end
      result.sub PROMPT, ''
    end
    
    def shell
      return @shell if @shell
      classpath = [Googly.config.compiler_jar]
      classpath << File.join(Googly.base_path, 'beanshell', 'bsh-2.0b4.jar')
      classpath << File.join(Googly.base_path, 'beanshell', 'Googly.jar')
      @shell = IO.popen("#{Googly.config.java} -classpath #{classpath.join(':')} bsh.Interpreter", 'r+')
      read_until_prompt
      @shell
    end
    
  end
  
end