goog.provide('myapp.hello');
goog.require('myapp.legume');

/**
 * @param {!String} subject
 */
myapp.hello = function(subject) {
  document.write(myapp.legume.hello({subject:subject}));
}

goog.exportSymbol('hello', myapp.hello)