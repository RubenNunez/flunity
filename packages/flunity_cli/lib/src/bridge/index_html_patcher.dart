const String _marker = '<!-- flunity:patch v1 -->';

const String _injection = '''
$_marker
<script src="flunity_bridge.js"></script>
<script>
  // Captured by Plan C's flunity_bridge.js shim. The shim is responsible for:
  // 1. defining window.flunity with .post / ._fromUnity / ._notifyReady,
  // 2. setting window.flunity._isReady = true once unityInstance is available,
  // 3. calling window.flunity._notifyReady?.() in the same tick.
</script>
''';

/// Inserts the Flunity bridge script tag + marker into a Unity WebGL index.html.
/// Idempotent: skips the patch if the marker is already present.
String patchUnityIndexHtml(String html) {
  if (html.contains(_marker)) return html;
  // Insert before </head> if present; otherwise before </body>; else append.
  final headIdx = html.indexOf('</head>');
  if (headIdx >= 0) {
    return html.substring(0, headIdx) + _injection + html.substring(headIdx);
  }
  final bodyIdx = html.indexOf('</body>');
  if (bodyIdx >= 0) {
    return html.substring(0, bodyIdx) + _injection + html.substring(bodyIdx);
  }
  return html + _injection;
}
