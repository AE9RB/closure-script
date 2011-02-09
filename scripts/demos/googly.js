goog.provide('googly');
goog.require('externs.jQuery');

googly.jqueryTest = function() {
  document.write('<p>Javascript jqueryTest() executed.</p>')
  $('.jqtest').hide()
}
goog.exportProperty(window, 'jqueryTest', googly.jqueryTest);

googly.simpleTest = function() {
  document.write('<p>Javascript simpleTest() executed.</p>')
}
goog.exportProperty(window, 'simpleTest', googly.simpleTest);

googly.warningNoOp = function(){
  function warningNoOp(){
    this.demonstrates = 'warnings in the Javascript console';
  }
}
