goog.provide('googly.jquerytest');
goog.require('vendor.jQuery')

googly.jquerytest = function() {
  document.write('The code ran.')
  $('.jqtest').hide()
}

goog.exportProperty(window, 'run_test', googly.jquerytest);


