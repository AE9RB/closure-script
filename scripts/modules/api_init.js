goog.provide('example.initializer.api');

goog.require('example.api');
goog.require('goog.module.ModuleManager');

// Like the settings module, the API module needs to inform the module manager
// when it has been loaded.
goog.module.ModuleManager.getInstance().setLoaded('api');