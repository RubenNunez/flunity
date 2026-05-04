import 'package:flunity_bridge/src/flunity_webgl_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlunityWebGLConfig.dev', () {
    test('defaults to 127.0.0.1:8080 with 10.0.2.2 emulator host', () {
      const c = FlunityWebGLConfig.dev();
      expect(c.mode, FlunityWebGLMode.dev);
      expect(c.host, '127.0.0.1');
      expect(c.port, 8080);
      expect(c.androidEmulatorHost, '10.0.2.2');
    });

    test('respects overrides', () {
      const c = FlunityWebGLConfig.dev(
        host: '10.0.0.5',
        port: 9000,
        androidEmulatorHost: '10.0.2.2',
      );
      expect(c.host, '10.0.0.5');
      expect(c.port, 9000);
    });

    test('resolveBaseUrl(): substitutes androidEmulatorHost when host is loopback on Android', () {
      const c = FlunityWebGLConfig.dev();
      expect(
        c.resolveBaseUrl(platform: TargetPlatform.android),
        'http://10.0.2.2:8080/',
      );
    });

    test('resolveBaseUrl(): keeps 127.0.0.1 on iOS / desktop', () {
      const c = FlunityWebGLConfig.dev();
      expect(c.resolveBaseUrl(platform: TargetPlatform.iOS), 'http://127.0.0.1:8080/');
      expect(c.resolveBaseUrl(platform: TargetPlatform.macOS), 'http://127.0.0.1:8080/');
    });

    test('resolveBaseUrl(): does NOT substitute when host is non-loopback (LAN)', () {
      const c = FlunityWebGLConfig.dev(host: '192.168.1.10');
      expect(
        c.resolveBaseUrl(platform: TargetPlatform.android),
        'http://192.168.1.10:8080/',
      );
    });
  });

  group('FlunityWebGLConfig.bundled', () {
    test('defaults to assets/unity_webgl/', () {
      final c = FlunityWebGLConfig.bundled();
      expect(c.mode, FlunityWebGLMode.bundled);
      expect(c.assetPath, 'assets/unity_webgl/');
    });

    test('normalizes assetPath to a trailing slash', () {
      expect(
        FlunityWebGLConfig.bundled(assetPath: 'assets/foo').assetPath,
        'assets/foo/',
      );
    });
  });
}
