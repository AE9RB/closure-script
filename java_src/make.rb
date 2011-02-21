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

#TODO move to Rakefile
raise "Remove old .class files before running make" unless Dir.glob("*.class").empty?
`javac -classpath ../closure-compiler/compiler.jar:../closure-templates/SoyToJsSrcCompiler.jar:../beanshell/bsh-core-2.0b4.jar ClosureScript.java`
`jar cf ../lib/shim.jar *.class javax/servlet/resources/README javax/servlet/resources/web-app_2_5.xsd`
%w{ClosureScript.class ClosureScript$1.class ClosureScript$SystemExitException.class ClosureScript$UnclosablePrintStream.class}.each {|f| File.unlink f rescue nil}