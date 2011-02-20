// Copyright 2011 The Closure Script Authors
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


import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintStream;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.MalformedURLException;
import java.lang.reflect.Method;
import java.util.Hashtable;

public class ClosureScript {
  
  static Hashtable<String, Method> libs = new Hashtable<String, Method>();
  
  //TODO there should be a way to determine the className with main()
  private static Method getMainMethod(String jar, String className) 
  throws ClassNotFoundException, NoSuchMethodException, MalformedURLException
  {
    if (!libs.containsKey(jar)) {
      File file = new File(jar);
      URL jarfile = new URL("jar", "","file:" + file.getAbsolutePath()+"!/");    
      URLClassLoader cl = URLClassLoader.newInstance(new URL[] {jarfile });   
      Class<?> loadedClass = cl.loadClass(className);
      Method m = loadedClass.getMethod("main", String[].class);
      libs.put(jar, m);
    }
    return libs.get(jar);
  }

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

  // This will load an executable jar and run it
  public static void run(String compiler_jar, String className, 
                             String outFileName, String errFileName, String[] args)
  throws ClassNotFoundException, NoSuchMethodException, IllegalAccessException,
         MalformedURLException, FileNotFoundException
  {
    Method main = getMainMethod(compiler_jar, className);
    PrintStream savedOut = System.out;
    PrintStream savedErr = System.err;
    PrintStream out = new PrintStream(new File(outFileName));
    PrintStream err = new PrintStream(new File(errFileName));
    try {
      System.setOut(out);
      System.setErr(err);
      disableSystemExit();
      main.invoke(main, new Object[]{args});
    } catch( java.lang.reflect.InvocationTargetException e ) {
      if (!(e.getCause() instanceof SystemExitException)) {
        err.println( e.getCause().getMessage() );
      }
    } finally {
      enableSystemExit();
      System.setErr(savedErr);
      System.setOut(savedOut);
    }  
    out.close();
    err.close();
  }

}
