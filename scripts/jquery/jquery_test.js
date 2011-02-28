goog.provide('jQueryTest');
goog.require('externs.jQuery.v1_4_4');

jQueryTest = function() {
  $('.jqtest').hide()
  document.write('<span>Compiled jQueryTest() executed.</span>')
}
goog.exportSymbol('jQueryTest', jQueryTest)
