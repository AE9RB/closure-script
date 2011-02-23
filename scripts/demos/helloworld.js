// This file was automatically generated from helloworld.soy.
// Please don't edit this file by hand.

goog.provide('googly.soy');

goog.require('soy');
goog.require('soy.StringBuilder');


/**
 * @param {Object.<string, *>=} opt_data
 * @param {soy.StringBuilder=} opt_sb
 * @return {string|undefined}
 * @notypecheck
 */
googly.soy.helloWorld = function(opt_data, opt_sb) {
  var output = opt_sb || new soy.StringBuilder();
  output.append('Hello world!!');
  if (!opt_sb) return output.toString();
};
