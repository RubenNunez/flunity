import 'package:flutter/foundation.dart';

enum FlunityWebGLMode { dev, bundled }

/// Configures how a [FlunityWebGLView] loads its Unity WebGL build.
@immutable
final class FlunityWebGLConfig {
  const FlunityWebGLConfig.dev({
    this.host = '127.0.0.1',
    this.port = 8080,
    this.androidEmulatorHost = '10.0.2.2',
  })  : mode = FlunityWebGLMode.dev,
        assetPath = '';

  const FlunityWebGLConfig._bundled(this.assetPath)
      : mode = FlunityWebGLMode.bundled,
        host = '',
        port = 0,
        androidEmulatorHost = '';

  factory FlunityWebGLConfig.bundled({String assetPath = 'assets/unity_webgl/'}) {
    final normalized = assetPath.endsWith('/') ? assetPath : '$assetPath/';
    return FlunityWebGLConfig._bundled(normalized);
  }

  final FlunityWebGLMode mode;

  // dev fields
  final String host;
  final int port;
  final String androidEmulatorHost;

  // bundled field
  final String assetPath;

  /// Resolves the base URL of the served WebGL build for the given [platform].
  /// In dev mode on Android, loopback hosts are swapped for [androidEmulatorHost].
  /// In bundled mode this returns the empty string — callers use [assetPath] instead.
  String resolveBaseUrl({required TargetPlatform platform}) {
    return switch (mode) {
      FlunityWebGLMode.bundled => '',
      FlunityWebGLMode.dev => 'http://${_resolveHost(platform)}:$port/',
    };
  }

  String _resolveHost(TargetPlatform platform) {
    final isAndroid = platform == TargetPlatform.android;
    final isLoopback = host == '127.0.0.1' || host == 'localhost';
    if (isAndroid && isLoopback) return androidEmulatorHost;
    return host;
  }
}
