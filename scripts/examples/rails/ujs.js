// Copyright 2011 The Closure Script Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// AND/OR -- You may also choose to use the MIT license instead. The dual-licensing
// intent is so that you may drop one if it doesn't fit your legal requirements.

// The MIT License
// 
// Copyright (c) 2011 The Closure Script Authors
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


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
