goog.provide('myapp.HelloWorld')

/** @constructor */
myapp.HelloWorld = function(message) {
  this.message_ = message;
}

myapp.HelloWorld.prototype.alert = function() {
  alert(this.message_);
}

goog.exportSymbol('myapp.HelloWorld', myapp.HelloWorld);
goog.exportProperty(myapp.HelloWorld, 'alert', myapp.HelloWorld.alert);