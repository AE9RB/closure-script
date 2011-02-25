# Copyright 2011 The Closure Script Authors
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


class Closure
  
  # Closure Script will manage a single BeanShell to run the Java tools.
  # This way we don't pay the Java startup costs on every compile job.
  class BeanShell
    
    PROMPT = /^bsh % $\Z/
    JAR = File.join(Closure.base_path, 'beanshell', 'bsh-core-2.0b4.jar')
    
    # @param classpath (Array)<string>
    def initialize(classpath=[])
      @semaphore = Mutex.new
      @classpath = classpath
      $cmdin = nil
    end
    
    # Run any Java command that BeanShell supports.
    # Recovers from error conditions when the Java process is killed.
    def run(command)
      begin
        return execute command
      rescue Errno::EPIPE
        # Shut down broken pipe; another will be started.
        $stderr.print "#{self.class}: restarting Java.\n"
        $pipe.close
        $pipe = nil
      end
      # This "second chance" will not rescue the error.
      execute command
    end
    
    protected
    
    # Executes a command on the REPL and returns the result.
    def execute(command)
      out = ''
      @semaphore.synchronize do
        unless $pipe
          classpath = [@classpath, JAR].flatten
          java_repl = "#{Closure.config.java} -classpath #{classpath.join(':').dump} bsh.Interpreter"
          $pipe = IO.popen(java_repl, 'w+')
          eat_startup = ''
          eat_startup << $pipe.readpartial(8192) until eat_startup =~ PROMPT
        end
        $pipe << command
        out << $pipe.readpartial(8192) until out =~ PROMPT
      end
      out.sub(PROMPT, '')
    end
    
  end
  
end