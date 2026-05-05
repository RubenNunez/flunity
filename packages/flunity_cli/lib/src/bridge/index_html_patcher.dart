const String _marker = '<!-- flunity:patch v1 -->';
const String _scriptInjection =
    '$_marker\n<script src="flunity_bridge.js"></script>';

/// Patches a Unity WebGL `index.html` to load the Flunity bridge JS shim and
/// call `window.flunity.ready(unityInstance)` once Unity has booted.
///
/// Idempotent: skipping if the marker is already present.
String patchUnityIndexHtml(String html) {
  if (html.contains(_marker)) return html;

  // 1. Insert the script tag right before </head>.
  final headIdx = html.indexOf('</head>');
  if (headIdx >= 0) {
    html =
        '${html.substring(0, headIdx)}$_scriptInjection\n  ${html.substring(headIdx)}';
  } else {
    // Fall back to before </body>; if neither exists, append.
    final bodyIdx = html.indexOf('</body>');
    if (bodyIdx >= 0) {
      html =
          '${html.substring(0, bodyIdx)}$_scriptInjection\n  ${html.substring(bodyIdx)}';
    } else {
      html = '$html\n$_scriptInjection\n';
    }
  }

  // 2. Insert window.flunity.ready(unityInstance) inside Unity's
  //    createUnityInstance(...).then((unityInstance) => { ... })
  //
  // Unity 2022 LTS template uses the pattern:
  //
  //   .then((unityInstance) => {
  //     document.querySelector("#unity-loading-bar").style.display = "none";
  //     ...
  //   })
  //
  // We append the ready() call as the LAST statement of that block.
  final thenPattern = RegExp(
    r'\.then\(\(unityInstance\)\s*=>\s*\{',
    multiLine: true,
  );
  final match = thenPattern.firstMatch(html);
  if (match == null) {
    // Couldn't find the createUnityInstance.then — leave it; the user can
    // wire ready() manually if they have a non-standard template.
    return html;
  }

  // Find the matching closing brace of the .then block.
  final openBrace = match.end - 1; // points at '{'
  var depth = 1;
  var i = openBrace + 1;
  while (i < html.length && depth > 0) {
    final c = html[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
    }
    if (depth == 0) break;
    i++;
  }
  if (i >= html.length) return html; // unmatched, give up

  // Insert before the closing brace.
  const readyCall = '''

                if (window.flunity && typeof window.flunity.ready === 'function') {
                  window.flunity.ready(unityInstance);
                }
              ''';
  return '${html.substring(0, i)}$readyCall${html.substring(i)}';
}
