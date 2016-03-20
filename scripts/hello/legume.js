// This file was automatically generated from legume.soy.
// Please don't edit this file by hand.

/**
 * @fileoverview Templates in namespace myapp.legume.
 */

goog.provide('myapp.legume');

goog.require('soy');
goog.require('soydata');


/**
 * @param {Object.<string, *>=} opt_data
 * @param {(null|undefined)=} opt_ignored
 * @return {string}
 * @suppress {checkTypes|uselessCode}
 */
myapp.legume.hello = function(opt_data, opt_ignored) {
  return 'Hello ' + soy.$$escapeHtml(opt_data.subject) + '!';
};
if (goog.DEBUG) {
  myapp.legume.hello.soyTemplateName = 'myapp.legume.hello';
}
