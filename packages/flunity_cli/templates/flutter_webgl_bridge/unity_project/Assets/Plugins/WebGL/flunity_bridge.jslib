mergeInto(LibraryManager.library, {
  // Unity calls this with a UTF8 char* JSON string. We hand it off to the JS
  // shim, which pushes it through flutter_inappwebview's JS handler.
  FlunityPostMessage: function(jsonPtr) {
    var json = UTF8ToString(jsonPtr);
    if (typeof window === 'undefined') return;
    if (window.flunity && typeof window.flunity._fromUnity === 'function') {
      window.flunity._fromUnity(json);
    } else {
      // Shim not loaded yet — buffer until it is.
      (window.__flunityPending = window.__flunityPending || []).push(json);
    }
  }
});
