// Copyright 2010 The Googlyscript Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


// The Google Closure javascript compiler calls System.exit() internally.
// I tried subclassing as they suggest, but the main System.exit() was at
// the end of the critical compiler run function.  Rather than take control
// of this important code which would need to be kept in sync with Google's
// releases, I use a SecurityManager to trap the System.exit() calls.
// BeanShell can't extend SecurityManager so this must be compiled.

// Once loaded up in a BeanShell or other REPL:
//   java -classpath bsh-2.0b4.jar:Googly.jar:../closure-compiler/compiler.jar bsh.Interpreter
// You may repeatedly request javascript compilations:
//   Googly.compile_js(new String[]{"--js", "../app/javascripts/test.js", "--js_output_file", "out.js", "--compilation_level", "ADVANCED_OPTIMIZATIONS"});

public class Googly {

  // This will be thrown when a captured block tries to System.exit()
  private static class SystemExitException extends SecurityException { }

  // Install a security manager that traps calls to System.exit()
  private static void disableSystemExit() {
    final SecurityManager securityManager = new SecurityManager() {
      public void checkPermission(java.security.Permission permission) {
        if (permission.getName().contains("exitVM")) {
          throw new SystemExitException();
        }
      }
    };
    System.setSecurityManager(securityManager);
  }

  // Remove the custom security manager so System.exit() works again
  private static void enableSystemExit() {
    System.setSecurityManager(null);
  }

  public static void compile_js(String[] args) {
  // public static void compile_js(String... args) {
    disableSystemExit();
    try {
      com.google.javascript.jscomp.CommandLineRunner.main(args);
    } catch( SystemExitException e ) {
    } finally {
      enableSystemExit() ;
    }  
  }


}