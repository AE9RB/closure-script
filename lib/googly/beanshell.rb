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
    
    PROMPT = /^bsh % $\Z/
    JAR = File.join(Googly.base_path, 'beanshell', 'bsh-core-2.0b4.jar')
    
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
      out = ''
      err = ''
      @semaphore.synchronize do
        unless $cmdin
          classpath = [@classpath, JAR].flatten
          java_repl = "#{Googly.config.java} -classpath #{classpath.join(':').dump} bsh.Interpreter"
          $cmdin, $cmdout, $cmderr = Open3::popen3(java_repl)
          eat_startup = ''
          eat_startup << $cmdout.readpartial(8192) until eat_startup =~ PROMPT
        end
        $cmdin << command
        # An extra thread collects stderr while we watch stdout for completion.
        running = true
        err_reader = Thread.new { err << $cmderr.readpartial(8192) while running }
        out << $cmdout.readpartial(8192) until out =~ PROMPT
        running = false
        Thread.exclusive { err_reader.terminate if err_reader.status == "sleep" }
        err_reader.join
        # Funny thing is, stdout sometimes finishes sending before stderr begins.
        err << $cmderr.read_nonblock(8192) while true rescue Errno::EAGAIN
      end
      [out.sub(PROMPT, ''), err]
    end

    
  end
  
end