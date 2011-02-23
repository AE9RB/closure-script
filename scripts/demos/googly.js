goog.provide('googly');
goog.require('externs.jQuery');
goog.require('googly.soy');

googly.jqueryTest = function() {
  $('.jqtest').hide()
  document.write('<p>Javascript jqueryTest() executed.</p>')
}
goog.exportSymbol('jqueryTest', googly.jqueryTest)

googly.simpleTest = function() {
  document.write('<p>Javascript simpleTest() executed.</p>')
}
goog.exportSymbol('simpleTest', googly.simpleTest)

googly.soyTest = function() {
  document.write('<p>Soy: ' + googly.soy.helloWorld() + '</p>')
}
goog.exportSymbol('soyTest', googly.soyTest)

googly.warningNoOp = function(){
  function warningNoOp(){
    this.demonstrates = 'warnings in the Javascript console';
  }
}
