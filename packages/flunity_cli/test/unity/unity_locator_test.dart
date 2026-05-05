import 'package:flunity_cli/src/unity/unity_locator.dart';
import 'package:test/test.dart';

void main() {
  test('UNITY_PATH wins when set and the file exists', () {
    final result = UnityLocator.locate(
      env: {'UNITY_PATH': '/fake/Unity'},
      fileExists: (path) => path == '/fake/Unity',
    );
    expect(result, '/fake/Unity');
  });

  test('UNITY_PATH is ignored when the file does not exist', () {
    final result = UnityLocator.locate(
      env: {'UNITY_PATH': '/missing'},
      fileExists: (_) => false,
    );
    expect(result, isNull);
  });

  test('returns null when no Unity is found anywhere', () {
    final result = UnityLocator.locate(env: const {}, fileExists: (_) => false);
    expect(result, isNull);
  });
}
