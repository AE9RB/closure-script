#TODO this won't report compile errors and has other bad things too
raise "Remove old .class files before running make" unless Dir.glob("*.class").empty?
`javac -classpath ../../closure-compiler/compiler.jar:../../beanshell/bsh-core-2.0b4.jar Googly.java`
`jar cf ../../lib/googly.jar *.class`
%w{Googly.class Googly$1.class Googly$SystemExitException.class Googly$UnclosablePrintStream.class}.each {|f| File.unlink f rescue nil}