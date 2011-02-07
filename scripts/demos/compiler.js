goog.provide('googly.demos.compiler');

googly.demos.compiler = function() {
  
  document.write('P' + 'A' + 'S' + 'S' + ': The code in test.js ran.')
}

goog.exportProperty(window, 'run_test', googly.demos.compiler);

var f= function(){
  this.demonstrates = 'warnings and errors in the Javascript console';
}