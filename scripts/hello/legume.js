// This file was automatically generated from legume.soy.
// Please don't edit this file by hand.

goog.provide('myapp.legume');

goog.require('soy');
goog.require('soy.StringBuilder');


/**
 * @param {Object.<string, *>=} opt_data
 * @param {soy.StringBuilder=} opt_sb
 * @return {string}
 * @notypecheck
 */
myapp.legume.hello = function(opt_data, opt_sb) {
  var output = opt_sb || new soy.StringBuilder();
  output.append('\tHello ', soy.$$escapeHtml(opt_data.subject), '!');
  return opt_sb ? '' : output.toString();
};
