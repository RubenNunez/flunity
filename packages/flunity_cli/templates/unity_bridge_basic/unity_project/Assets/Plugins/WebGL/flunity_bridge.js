/* Flunity bridge JS shim (~80 lines).
 *
 * Contract:
 *   - Defines window.flunity with .post(json), ._fromUnity(json), .ready(unityInstance)
 *   - Sets window.flunity._isReady = true once unityInstance is available, AND
 *     calls window.flunity._notifyReady?.() in the same synchronous block so the
 *     Flutter-side onLoadStop hook can register a notifier and not miss the edge.
 *   - Buffers Dart→Unity messages sent before unityInstance exists.
 *
 * The patcher (flunity_cli's index_html_patcher.dart) inserts a <script src="flunity_bridge.js">
 * tag in the WebGL build's index.html. The bridge_init command also wraps the
 * existing createUnityInstance call so we capture the resulting unityInstance.
 */
(function () {
  if (window.flunity) return; // already loaded
  var pendingFromDart = [];
  var ready = false;
  var unityInstance = null;

  // Drain anything the .jslib buffered before the shim arrived.
  if (Array.isArray(window.__flunityPending)) {
    var buffered = window.__flunityPending;
    window.__flunityPending = null;
    setTimeout(function () {
      buffered.forEach(function (json) {
        try { window.flunity._fromUnity(json); } catch (e) {}
      });
    }, 0);
  }

  window.flunity = {
    _isReady: false,
    _notifyReady: null,

    /** Called by Dart via evaluateJavascript. Routes JSON into Unity. */
    post: function (json) {
      if (unityInstance && typeof unityInstance.SendMessage === 'function') {
        unityInstance.SendMessage('[FlunityBridge]', 'ReceiveFromFlutter', json);
      } else {
        pendingFromDart.push(json);
      }
    },

    /** Called by the .jslib extern. Forwards to the Flutter-side handler. */
    _fromUnity: function (json) {
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        window.flutter_inappwebview.callHandler('flunity', json);
      }
    },

    /**
     * Called by index.html (after bridge_init's patcher wraps
     * createUnityInstance) once unityInstance resolves.
     */
    ready: function (instance) {
      unityInstance = instance;
      ready = true;
      window.flunity._isReady = true;
      // Flush any messages Dart sent before we were ready.
      var pending = pendingFromDart;
      pendingFromDart = [];
      pending.forEach(function (json) {
        instance.SendMessage('[FlunityBridge]', 'ReceiveFromFlutter', json);
      });
      // Notify the Flutter-side hook (if registered).
      if (typeof window.flunity._notifyReady === 'function') {
        try { window.flunity._notifyReady(); } catch (e) {}
      }
    }
  };
})();
