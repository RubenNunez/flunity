import 'dart:io';

import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:path/path.dart' as p;

class PrepareSummary {
  PrepareSummary({
    required this.shimCopied,
    required this.indexHtmlPatched,
  });
  final bool shimCopied;
  final bool indexHtmlPatched;
}

/// Prepares a Unity WebGL build directory for the Flunity bridge by:
///
///   1. Copying `flunity_bridge.js` from the project's
///      `unity_project/Assets/Plugins/WebGL/` into the build dir next to
///      `index.html`.
///   2. Patching `index.html` to load the shim AND call
///      `window.flunity.ready(unityInstance)`.
///
/// Idempotent and safe to run on every serve/copy.
Future<PrepareSummary> prepareWebGLBuild({
  required String buildDir,
  required String shimSourcePath,
}) async {
  var shimCopied = false;
  var patched = false;

  final shimSrc = File(shimSourcePath);
  final shimDst = File(p.join(buildDir, 'flunity_bridge.js'));
  if (shimSrc.existsSync()) {
    if (!shimDst.existsSync() ||
        shimDst.readAsStringSync() != shimSrc.readAsStringSync()) {
      shimDst.writeAsStringSync(shimSrc.readAsStringSync());
      shimCopied = true;
    }
  }

  final indexHtml = File(p.join(buildDir, 'index.html'));
  if (indexHtml.existsSync()) {
    final original = indexHtml.readAsStringSync();
    final updated = patchUnityIndexHtml(original);
    if (updated != original) {
      indexHtml.writeAsStringSync(updated);
      patched = true;
    }
  }

  return PrepareSummary(shimCopied: shimCopied, indexHtmlPatched: patched);
}
