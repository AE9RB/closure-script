require 'open3'

class Googly
  
  # Googlyscript will manage a single BeanShell to run the Java tools.
  # This way we don't pay the Java startup costs on every compile job.
  class BeanShell
    
    # Run any Java command that BeanShell supports.
    # Recovers from error conditions when the Java process is killed.
    def run(command)
      begin
        return execute command
      rescue Errno::EPIPE
        # Shut down broken pipe; another will be started.
        $cmdin.close
        $cmdout.close
        $cmderr.close
        $cmdin = nil
      end
      # This "second chance" will not rescue the error.
      puts "Java BeanShell is restarting (this should not happen)"
      execute command
    end
    
    protected
    
    # Executes a command on the REPL and returns the result.
    def execute(command)
      prompt = /^bsh % $\Z/
      unless $cmdin
        classpath = [Googly.config.compiler_jar]
        classpath << File.join(Googly.base_path, 'beanshell', 'bsh-core-2.0b4.jar')
        classpath << File.join(Googly.base_path, 'lib', 'googly.jar')
        java_repl = "#{Googly.config.java} -classpath #{classpath.join(':')} bsh.Interpreter"
        $cmdin, $cmdout, $cmderr = Open3::popen3(java_repl)
        eat_startup = ''
        eat_startup << $cmdout.readpartial(8192) until eat_startup =~ prompt
      end
      $cmdin << command
      out = ''
      err = ''
      until out =~ prompt
        sleep 0.05 # wait at start and collect results 20 times per second
        out << $cmdout.read_nonblock(8192) while true rescue Errno::EAGAIN
        err << $cmderr.read_nonblock(8192) while true rescue Errno::EAGAIN
      end
      [out.sub(prompt, ''), err]
    end

    
  end
  
end