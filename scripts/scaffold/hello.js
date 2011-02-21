goog.provide('myapp.hello');
 
myapp.hello = function(subject) {
  document.write('<p>Hello ' + subject + '!</p>')
}

goog.exportSymbol('hello', myapp.hello)