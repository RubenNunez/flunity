import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:test/test.dart';

void main() {
  test('inserts script tag and ready hook on first run', () {
    const original = '''
<!doctype html>
<html><body>
<script>
  createUnityInstance(canvas, config).then((u) => { window.unityInstance = u; });
</script>
</body></html>
''';
    final patched = patchUnityIndexHtml(original);
    expect(patched, contains('<!-- flunity:patch v1 -->'));
    expect(patched, contains('flunity_bridge.js'));
    expect(patched, contains('window.flunity._isReady = true'));
  });

  test('idempotent: patching twice does not duplicate', () {
    const original = '<!doctype html><html><body></body></html>';
    final once = patchUnityIndexHtml(original);
    final twice = patchUnityIndexHtml(once);
    expect(once, twice);
  });
}
