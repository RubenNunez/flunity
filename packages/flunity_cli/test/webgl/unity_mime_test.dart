import 'package:flunity_cli/src/webgl/unity_mime.dart';
import 'package:test/test.dart';

void main() {
  test('Unity-specific MIME types', () {
    expect(unityMimeType('app.wasm'), 'application/wasm');
    expect(unityMimeType('app.data'), 'application/octet-stream');
    expect(unityMimeType('app.symbols.json'), 'application/json');
    expect(unityMimeType('app.framework.js'), 'application/javascript');
  });

  test('precompressed extensions strip and remap', () {
    expect(unityMimeType('app.wasm.br'), 'application/wasm');
    expect(unityMimeType('app.wasm.gz'), 'application/wasm');
    expect(unityMimeType('app.data.br'), 'application/octet-stream');
  });

  test('returns null for genuinely unknown extensions', () {
    expect(unityMimeType('mystery.xyz'), isNull);
  });
}
