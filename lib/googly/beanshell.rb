# Copyright 2010 The Googlyscript Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'open3'

class Googly
  
  # Googlyscript will manage a single BeanShell to run the Java tools.
  # This way we don't pay the Java startup costs on every compile job.
  class BeanShell
    
    def initialize
      @semaphore = Mutex.new
    end
    
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
      out = ''
      err = ''
      @semaphore.synchronize do
        unless $cmdin
          classpath = [Googly.config.compiler_jar]
          classpath << File.join(Googly.base_path, 'beanshell', 'bsh-core-2.0b4.jar')
          classpath << File.join(Googly.base_path, 'lib', 'googly.jar')
          #TODO spaces won't be escaped
          java_repl = "#{Googly.config.java} -classpath #{classpath.join(':')} bsh.Interpreter"
          $cmdin, $cmdout, $cmderr = Open3::popen3(java_repl)
          eat_startup = ''
          eat_startup << $cmdout.readpartial(8192) until eat_startup =~ prompt
        end
        $cmdin << command
        until out =~ prompt
          #TODO make threaded; this will save ~0.025 seconds per execution
          sleep 0.05 # wait at start and collect results 20 times per second
          out << $cmdout.read_nonblock(8192) while true rescue Errno::EAGAIN
          err << $cmderr.read_nonblock(8192) while true rescue Errno::EAGAIN
        end
      end
      [out.sub(prompt, ''), err]
    end

    
  end
  
end