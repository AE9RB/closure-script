goog.provide('rails.ujs');

goog.require('goog.events');
goog.require('goog.dom');
goog.require('goog.dom.forms');
goog.require('goog.net.XhrIo');


goog.events.listen(document, 'click', function(e) {
  if (e.target.hasAttribute('data-confirm')) {
    if (!confirm(e.target.getAttribute('data-confirm'))) {
      e.preventDefault();
      e.stopPropagation();
    }
  }
}, true);

goog.events.listen(document, 'click', function(e) {
  if (e.target.hasAttribute('data-remote')) {
    e.preventDefault();
    rails.ujs.handleRemote(e.target);
  } else if (e.target.hasAttribute('data-method')) {
    e.preventDefault();
    rails.ujs.handleMethod(e.target);
  }
}, false);

goog.events.listen(document, 'submit', function(e) {
  if (e.target.hasAttribute('data-remote')) {
    e.preventDefault();
    rails.ujs.handleRemote(e.target);
  }
}, true);


rails.ujs.dispatchEvent = function(el, type) {
  var evObj = document.createEvent('Event');
  evObj.initEvent(type, true, true);
  el.dispatchEvent(evObj);
}


rails.ujs.handleRemote = function(el) {
  var data, method, url;
  if (el.nodeName == goog.dom.TagName.FORM) {
    data = goog.dom.forms.getFormDataString(el)
    method = el.getAttribute('method') || 'POST';
    url = el.getAttribute('action');
  } else {
    method = el.getAttribute('data-method') || 'GET';
    url = el.getAttribute('href');
  }
  var xhr = new goog.net.XhrIo();
  xhr.onreadystatechange = function() {
    if (xhr.readyState == goog.net.XmlHttp.ReadyState.COMPLETE) {
      goog.events.dispatchEvent(el, new goog.events.Event('ajax:complete'));
    };
  };
  xhr.send(url, method.toUpperCase(), data);
  if (xhr.isSuccess()) {
    goog.events.dispatchEvent(el, new goog.events.Event('ajax:success'));
  } else {
    goog.events.dispatchEvent(el, new goog.events.Event('ajax:failure'));
  };
}


rails.ujs.handleMethod = function(element) {
  var method = element.getAttribute('data-method').toLowerCase();
  var url = element.getAttribute('href');
  var form = goog.dom.createDom('form', { method: "POST", action: url, style: "display: none;" })
  goog.dom.appendChild(element, form)
  if (method !== 'post') {
    goog.dom.appendChild(form,
      goog.dom.createDom('input', { type: 'hidden', name: '_method', value: method })
    )
  }
  var csrf_param, csrf_token;
  goog.array.forEach(
    goog.dom.getElementsByTagNameAndClass('meta'),
    function(e) {
      var name = e.getAttribute('name')
      if (name == 'csrf-param') {
        csrf_param = e.getAttribute('content')
      } else if (name == 'csrf-token') {
        csrf_token = e.getAttribute('content')
      }
    }
  );
  if (csrf_param) {
    goog.dom.appendChild(form,
      goog.dom.createDom('input', { type: 'hidden', name: csrf_param, value: csrf_token })
    );
  }
  form.submit();
}
