goog.provide('googly');
goog.require('externs.jQuery');

googly.jqueryTest = function() {
  document.write('<p>Javascript jqueryTest() executed.</p>')
  $('.jqtest').hide()
}
goog.exportSymbol('jqueryTest', googly.jqueryTest)

googly.simpleTest = function() {
  document.write('<p>Javascript simpleTest() executed.</p>')
}
goog.exportSymbol('simpleTest', googly.simpleTest)

googly.helloWorld = function() {
  document.write('<p>Hello from the Closure Script demo code.</p>')
}
goog.exportSymbol('helloWorld', googly.helloWorld)

googly.warningNoOp = function(){
  function warningNoOp(){
    this.demonstrates = 'warnings in the Javascript console';
  }
}
