goog.provide('jQueryTest');
goog.require('externs.jQuery.v1_4_4');

jQueryTest = function() {
  $('.jqtest').hide()
  document.write('<p>Compiled jQueryTest() executed.</p>')
}
goog.exportSymbol('jQueryTest', jQueryTest)
