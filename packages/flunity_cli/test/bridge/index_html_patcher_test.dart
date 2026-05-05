import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:test/test.dart';

void main() {
  test('inserts script tag and ready hook on first run', () {
    const original = '''
<!doctype html>
<html><head></head><body>
<script>
  createUnityInstance(canvas, config).then((unityInstance) => { window.unityInstance = u; });
</script>
</body></html>
''';
    final patched = patchUnityIndexHtml(original);
    expect(patched, contains('<!-- flunity:patch v1 -->'));
    expect(patched, contains('flunity_bridge.js'));
    expect(patched, contains('window.flunity.ready(unityInstance)'));
  });

  test('idempotent: patching twice does not duplicate', () {
    const original = '<!doctype html><html><body></body></html>';
    final once = patchUnityIndexHtml(original);
    final twice = patchUnityIndexHtml(once);
    expect(once, twice);
  });

  test('inserts window.flunity.ready inside createUnityInstance.then', () {
    const original = '''<!doctype html>
<html><head></head><body>
<script>
  createUnityInstance(canvas, config).then((unityInstance) => {
    document.querySelector("#bar").style.display = "none";
  });
</script>
</body></html>
''';
    final patched = patchUnityIndexHtml(original);
    expect(patched, contains('window.flunity.ready(unityInstance)'));
  });

  test('handles missing createUnityInstance gracefully', () {
    const original = '<html><head></head><body></body></html>';
    final patched = patchUnityIndexHtml(original);
    expect(patched, contains('flunity:patch v1'));
    expect(patched, isNot(contains('window.flunity.ready')));
  });
}
