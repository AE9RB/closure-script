goog.provide('googly.rails');

goog.require('goog.events');

goog.events.listen(document, 'click', function(event) {
  if (event.target.hasAttribute('data-confirm')) {
    if (!confirm(event.target.getAttribute('data-confirm'))) {
      event.preventDefault();
    }
  }
});
