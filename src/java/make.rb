#TODO this won't report compile errors and has other bad things too
raise "Remove old .class files before running make" unless Dir.glob("*.class").length == 0
`javac -classpath ../../closure-compiler/compiler.jar Googly.java`
`jar cf ../../lib/googly.jar *.class`
%w{Googly.class Googly$1.class Googly$SystemExitException.class}.each {|f| File.unlink f}