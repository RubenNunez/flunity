# Plan A — Workspace + `flunity_bridge` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the Flunity Melos monorepo and build the `flunity_bridge` Flutter package end-to-end with full unit-test coverage, so the rest of the project (CLI, templates) has a solid foundation to consume.

**Architecture:** Melos workspace at the repo root. One Flutter package `packages/flunity_bridge/` with a sealed `FlunityMessage` hierarchy, a `FlunityWebGLConfig` dev/bundled switch, a `FlunityWebGLController` built over a thin `MessageTransport` interface (so the round-trip is testable without a real WebView), and a `FlunityWebGLView` widget that wires the real `flutter_inappwebview` transport.

**Tech Stack:** Dart `^3.5.0`, Flutter `^3.24.0`, Melos, `flutter_inappwebview ^6.x`, `flutter_test`.

**Spec reference:** `docs/superpowers/specs/2026-05-04-flunity-v1-design.md` §3, §4, §6, §11.

---

## Prerequisites

Before starting, the engineer must have:
- Flutter SDK `>=3.24.0` on PATH (`flutter --version`)
- Dart SDK `>=3.5.0` (bundled with Flutter)
- Repo cloned at `/Volumes/Transcend/Projects/flunity` with `origin` = `git@github.com:RubenNunez/flunity.git`, branch `main` already containing the design spec

If `melos` isn't installed:
```
dart pub global activate melos
```
And ensure `$HOME/.pub-cache/bin` is on PATH.

---

## File Structure

What this plan creates (paths relative to repo root):

```
flunity/
├── LICENSE                                            (MIT, repo root)
├── README.md                                          (project pitch + status)
├── CHANGELOG.md                                       (Keep-a-Changelog format)
├── analysis_options.yaml                              (workspace lints)
├── melos.yaml                                         (Melos workspace config)
├── pubspec.yaml                                       (root workspace pubspec)
└── packages/
    └── flunity_bridge/
        ├── pubspec.yaml
        ├── analysis_options.yaml                      (extends repo root)
        ├── README.md
        ├── CHANGELOG.md
        ├── lib/
        │   ├── flunity_bridge.dart                    (public exports)
        │   └── src/
        │       ├── flunity_message.dart               (sealed FlunityMessage + RawMessage + registry)
        │       ├── messages/
        │       │   ├── ping.dart
        │       │   ├── pong.dart
        │       │   ├── load_scene.dart
        │       │   └── scene_ready.dart
        │       ├── flunity_webgl_config.dart          (.dev() / .bundled() factories)
        │       ├── transport/
        │       │   ├── message_transport.dart         (abstract interface)
        │       │   └── inapp_webview_transport.dart   (flutter_inappwebview impl)
        │       ├── flunity_webgl_controller.dart      (queues, parses, exposes stream)
        │       └── flunity_webgl_view.dart            (widget glue)
        └── test/
            ├── flunity_message_test.dart
            ├── messages/
            │   ├── ping_test.dart
            │   ├── pong_test.dart
            │   ├── load_scene_test.dart
            │   └── scene_ready_test.dart
            ├── flunity_webgl_config_test.dart
            ├── transport/
            │   └── fake_transport.dart                (test helper, not under lib/)
            └── flunity_webgl_controller_test.dart
```

The `FlunityWebGLView` widget itself is not unit-tested in this plan — it's thin glue over `flutter_inappwebview`, which doesn't widget-test cleanly without a real platform view. It's exercised by Plan C's example smoke test.

---

## Phase 1 — Workspace bootstrap

### Task 1: Create LICENSE (MIT)

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Write LICENSE**

```
MIT License

Copyright (c) 2026 Ruben Nunez

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Task 2: Workspace root pubspec and analysis_options

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`

- [ ] **Step 1: Write root pubspec.yaml**

```yaml
name: flunity_workspace
publish_to: none
environment:
  sdk: ^3.5.0

dev_dependencies:
  melos: ^6.0.0
```

- [ ] **Step 2: Write analysis_options.yaml**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    todo: ignore

linter:
  rules:
    - always_declare_return_types
    - avoid_print
    - directives_ordering
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - sort_pub_dependencies
    - unawaited_futures
    - use_super_parameters
```

### Task 3: Melos workspace config

**Files:**
- Create: `melos.yaml`

- [ ] **Step 1: Write melos.yaml**

```yaml
name: flunity
repository: https://github.com/RubenNunez/flunity

packages:
  - packages/**
  - examples/**

command:
  bootstrap:
    runPubGetInParallel: true
  version:
    branch: main
    workspaceChangelog: true

scripts:
  analyze:
    description: Analyze every package
    run: melos exec -- "dart analyze ."
  test:
    description: Run tests in every package
    run: melos exec --dir-exists=test -- "flutter test"
  format:
    description: Format every Dart file
    run: melos exec -- "dart format ."
  format-check:
    description: Check formatting (CI)
    run: melos exec -- "dart format --output=none --set-exit-if-changed ."
```

### Task 4: README skeleton and CHANGELOG

**Files:**
- Create: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Write README.md**

```markdown
# Flunity

> Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.

**Status: pre-alpha.** Under active development. Public API may change without notice until `0.1.0`.

Flunity is a development companion for Flutter + Unity projects. The first supported workflow is lightweight Unity WebGL scenes loaded inside Flutter through a WebView. Native Unity Android/iOS targets are on the roadmap but not yet implemented.

## Packages

| Package | Description |
| --- | --- |
| [`flunity_bridge`](packages/flunity_bridge) | Flutter package: `FlunityWebGLView`, controller, message types, dev/bundled config. |
| `flunity_cli` *(coming soon)* | The `flunity` executable: project scaffolding, dev server, asset bundling, bridge init. |

## Documentation

See [`docs/`](docs/) — getting started, project structure, WebGL workflow, bridge API, production build, Android emulator notes, and the native roadmap.

## License

MIT. See [LICENSE](LICENSE).
```

- [ ] **Step 2: Write CHANGELOG.md**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial design spec (`docs/superpowers/specs/2026-05-04-flunity-v1-design.md`).
- Melos workspace bootstrap.
- `flunity_bridge` package with sealed `FlunityMessage` hierarchy, `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.
```

### Task 5: Bootstrap Melos and verify

- [ ] **Step 1: Install melos if missing**

Run: `dart pub global activate melos`
Expected: `Activated melos x.y.z.`

- [ ] **Step 2: Bootstrap workspace**

Run from repo root: `melos bootstrap`
Expected: bootstraps without error (no packages yet, but melos validates the workspace and writes `.dart_tool/` artifacts).

- [ ] **Step 3: Add melos artifacts to .gitignore**

Modify: `.gitignore`

Append (only if missing):

```
.melos_tool/
```

(`.dart_tool/` and `pubspec.lock` are already ignored from the spec commit.)

### Task 6: Commit Phase 1

- [ ] **Step 1: Stage and commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add LICENSE README.md CHANGELOG.md pubspec.yaml analysis_options.yaml melos.yaml .gitignore
git -C /Volumes/Transcend/Projects/flunity commit -m "$(cat <<'EOF'
chore: bootstrap Flunity Melos workspace

Add repo-root LICENSE (MIT), README, CHANGELOG, workspace pubspec,
shared analysis_options, and melos.yaml. No packages yet.
EOF
)"
```

Expected: clean commit on `main`.

---

## Phase 2 — `flunity_bridge` package skeleton

### Task 7: Create package directory + pubspec

**Files:**
- Create: `packages/flunity_bridge/pubspec.yaml`
- Create: `packages/flunity_bridge/analysis_options.yaml`
- Create: `packages/flunity_bridge/README.md`
- Create: `packages/flunity_bridge/CHANGELOG.md`

- [ ] **Step 1: Write `packages/flunity_bridge/pubspec.yaml`**

```yaml
name: flunity_bridge
description: Flutter package for embedding Unity WebGL builds inside a Flutter app, with a typed Flutter <-> Unity message bridge.
version: 0.1.0
homepage: https://github.com/RubenNunez/flunity
repository: https://github.com/RubenNunez/flunity
issue_tracker: https://github.com/RubenNunez/flunity/issues

environment:
  flutter: ^3.24.0
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_inappwebview: ^6.0.0
  meta: ^1.12.0

dev_dependencies:
  flutter_lints: ^4.0.0
  flutter_test:
    sdk: flutter
```

- [ ] **Step 2: Write `packages/flunity_bridge/analysis_options.yaml`**

```yaml
include: ../../analysis_options.yaml
```

- [ ] **Step 3: Write `packages/flunity_bridge/README.md`**

```markdown
# flunity_bridge

Flutter package providing the runtime side of [Flunity](https://github.com/RubenNunez/flunity): a `FlunityWebGLView` widget, a controller, sealed `FlunityMessage` types, and a dev/bundled config switch for running Unity WebGL inside Flutter.

Use the `flunity_cli` tool to scaffold projects that consume this package.

## Quickstart

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

FlunityWebGLView(
  config: const FlunityWebGLConfig.dev(port: 8080),
  onReady: (controller) {
    controller.send(const Ping(nonce: 'hello'));
  },
  onMessage: (msg) {
    if (msg is Pong) print('Got pong: ${msg.nonce}');
  },
);
```

## License

MIT.
```

- [ ] **Step 4: Write `packages/flunity_bridge/CHANGELOG.md`**

```markdown
# Changelog

## [Unreleased]

### Added
- Initial release: sealed `FlunityMessage` hierarchy, `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.
```

### Task 8: Empty public entrypoint + bootstrap

**Files:**
- Create: `packages/flunity_bridge/lib/flunity_bridge.dart`

- [ ] **Step 1: Write empty exports file**

```dart
/// Flunity bridge: embed Unity WebGL inside Flutter with a typed message bridge.
library flunity_bridge;

// Exports filled in as the package grows.
```

- [ ] **Step 2: Bootstrap from repo root**

Run: `melos bootstrap`
Expected: `flunity_bridge` is detected; deps install without error.

- [ ] **Step 3: Verify package analyzes clean**

Run: `cd packages/flunity_bridge && flutter analyze`
Expected: `No issues found!`

### Task 9: Commit Phase 2

- [ ] **Step 1: Stage and commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge
git -C /Volumes/Transcend/Projects/flunity commit -m "$(cat <<'EOF'
feat(flunity_bridge): add empty package skeleton

pubspec, analysis_options extending workspace lints, README,
CHANGELOG, and an empty library entrypoint. Melos bootstraps
clean and `flutter analyze` passes.
EOF
)"
```

---

## Phase 3 — `FlunityMessage` sealed hierarchy

### Task 10: Sealed `FlunityMessage` + `RawMessage` (TDD)

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_message.dart`
- Create: `packages/flunity_bridge/test/flunity_message_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/flunity_bridge/test/flunity_message_test.dart`:

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawMessage', () {
    test('serializes to {type, payload} envelope', () {
      const msg = RawMessage(type: 'custom', payload: {'a': 1});
      expect(msg.toJson(), {'type': 'custom', 'payload': {'a': 1}});
    });

    test('round-trips via fromJson', () {
      const original = RawMessage(type: 'custom', payload: {'a': 1});
      final restored = FlunityMessage.fromJson(original.toJson());
      expect(restored, isA<RawMessage>());
      final raw = restored as RawMessage;
      expect(raw.type, 'custom');
      expect(raw.payload, {'a': 1});
    });

    test('fromJson throws FormatException when type is missing', () {
      expect(
        () => FlunityMessage.fromJson({'payload': {}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson tolerates missing payload as empty map', () {
      final msg = FlunityMessage.fromJson({'type': 'noop'}) as RawMessage;
      expect(msg.payload, <String, Object?>{});
    });
  });
}
```

- [ ] **Step 2: Run, confirm fail**

Run: `cd packages/flunity_bridge && flutter test test/flunity_message_test.dart`
Expected: compile error or "Failed to load" — `flunity_message.dart` doesn't exist yet.

- [ ] **Step 3: Implement `flunity_message.dart`**

```dart
import 'package:meta/meta.dart';

/// Wire-format envelope used by every Flunity message: `{"type": ..., "payload": ...}`.
@immutable
sealed class FlunityMessage {
  const FlunityMessage();

  String get type;
  Map<String, Object?> get payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'payload': payload,
      };

  /// Parses a JSON map into a typed [FlunityMessage]. Unknown `type`s fall back
  /// to [RawMessage] so future Unity-side message types don't break consumers.
  static FlunityMessage fromJson(Map<String, Object?> json) {
    final dynamic rawType = json['type'];
    if (rawType is! String) {
      throw const FormatException('FlunityMessage requires a string "type" field');
    }
    final Map<String, Object?> payload = switch (json['payload']) {
      final Map<String, Object?> map => map,
      null => const <String, Object?>{},
      _ => throw const FormatException('FlunityMessage "payload" must be a JSON object'),
    };
    final factory = _registry[rawType];
    if (factory != null) {
      return factory(payload);
    }
    return RawMessage(type: rawType, payload: payload);
  }

  static final Map<String, FlunityMessage Function(Map<String, Object?>)> _registry =
      <String, FlunityMessage Function(Map<String, Object?>)>{};

  /// Registers a factory for a typed message subclass. Used by built-in message
  /// classes; callers can register their own types too (overrides allowed).
  static void registerType(
    String type,
    FlunityMessage Function(Map<String, Object?> payload) factory,
  ) {
    _registry[type] = factory;
  }
}

/// Escape hatch for messages whose dart type isn't known to this package.
final class RawMessage extends FlunityMessage {
  const RawMessage({required this.type, required this.payload});

  @override
  final String type;

  @override
  final Map<String, Object?> payload;

  @override
  bool operator ==(Object other) =>
      other is RawMessage &&
      other.type == type &&
      _mapEquals(other.payload, payload);

  @override
  int get hashCode => Object.hash(type, _mapHash(payload));
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<String, Object?> map) =>
    Object.hashAllUnordered(map.entries.map((e) => Object.hash(e.key, e.value)));
```

- [ ] **Step 4: Run, confirm pass**

Run: `flutter test test/flunity_message_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/flunity_message.dart packages/flunity_bridge/test/flunity_message_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): sealed FlunityMessage + RawMessage with type registry"
```

---

## Phase 4 — Built-in message types

Each built-in message follows the same pattern: a `final class` extending `FlunityMessage`, a static `_register()` call, a static `register()` public API, and a TDD pair. We register all built-ins from a single bootstrap function called by the public library entrypoint so consumers don't need to call register manually.

### Task 11: `Ping` message (TDD)

**Files:**
- Create: `packages/flunity_bridge/lib/src/messages/ping.dart`
- Create: `packages/flunity_bridge/test/messages/ping_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/flunity_bridge/test/messages/ping_test.dart`:

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(Ping.register);

  test('Ping serializes to {type: "ping", payload: {nonce}}', () {
    const msg = Ping(nonce: 'abc');
    expect(msg.toJson(), {
      'type': 'ping',
      'payload': {'nonce': 'abc'},
    });
  });

  test('Ping round-trips via FlunityMessage.fromJson', () {
    final restored = FlunityMessage.fromJson(const Ping(nonce: 'abc').toJson());
    expect(restored, isA<Ping>());
    expect((restored as Ping).nonce, 'abc');
  });

  test('Ping equality + hashCode', () {
    expect(const Ping(nonce: 'x'), const Ping(nonce: 'x'));
    expect(const Ping(nonce: 'x').hashCode, const Ping(nonce: 'x').hashCode);
    expect(const Ping(nonce: 'x'), isNot(const Ping(nonce: 'y')));
  });

  test('Ping.fromJson throws on missing nonce', () {
    expect(
      () => FlunityMessage.fromJson({'type': 'ping', 'payload': {}}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

- [ ] **Step 2: Run, confirm fail**

Run: `flutter test test/messages/ping_test.dart`
Expected: import error — `ping.dart` doesn't exist.

- [ ] **Step 3: Implement `ping.dart`**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class Ping extends FlunityMessage {
  const Ping({required this.nonce});

  static const String typeName = 'ping';

  /// Registers `Ping` with [FlunityMessage]'s parser. Idempotent.
  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic n = payload['nonce'];
      if (n is! String) {
        throw const FormatException('Ping payload requires string "nonce"');
      }
      return Ping(nonce: n);
    });
  }

  final String nonce;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'nonce': nonce};

  @override
  bool operator ==(Object other) => other is Ping && other.nonce == nonce;

  @override
  int get hashCode => Object.hash('ping', nonce);
}
```

- [ ] **Step 4: Run, confirm pass**

Run: `flutter test test/messages/ping_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/messages/ping.dart packages/flunity_bridge/test/messages/ping_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): Ping message"
```

### Task 12: `Pong` message (TDD)

**Files:**
- Create: `packages/flunity_bridge/lib/src/messages/pong.dart`
- Create: `packages/flunity_bridge/test/messages/pong_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(Pong.register);

  test('Pong serializes to {type: "pong", payload: {nonce}}', () {
    expect(const Pong(nonce: 'abc').toJson(), {
      'type': 'pong',
      'payload': {'nonce': 'abc'},
    });
  });

  test('Pong round-trips via fromJson', () {
    final restored = FlunityMessage.fromJson(const Pong(nonce: 'abc').toJson());
    expect((restored as Pong).nonce, 'abc');
  });

  test('Pong equality', () {
    expect(const Pong(nonce: 'x'), const Pong(nonce: 'x'));
    expect(const Pong(nonce: 'x'), isNot(const Pong(nonce: 'y')));
  });

  test('Pong.fromJson throws on missing nonce', () {
    expect(
      () => FlunityMessage.fromJson({'type': 'pong', 'payload': {}}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

- [ ] **Step 2: Run, confirm fail**

Run: `flutter test test/messages/pong_test.dart`
Expected: import error.

- [ ] **Step 3: Implement `pong.dart`**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class Pong extends FlunityMessage {
  const Pong({required this.nonce});

  static const String typeName = 'pong';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic n = payload['nonce'];
      if (n is! String) {
        throw const FormatException('Pong payload requires string "nonce"');
      }
      return Pong(nonce: n);
    });
  }

  final String nonce;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'nonce': nonce};

  @override
  bool operator ==(Object other) => other is Pong && other.nonce == nonce;

  @override
  int get hashCode => Object.hash('pong', nonce);
}
```

- [ ] **Step 4: Run, confirm pass**

Expected: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/messages/pong.dart packages/flunity_bridge/test/messages/pong_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): Pong message"
```

### Task 13: `LoadScene` message (TDD)

**Files:**
- Create: `packages/flunity_bridge/lib/src/messages/load_scene.dart`
- Create: `packages/flunity_bridge/test/messages/load_scene_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(LoadScene.register);

  test('serializes to {type: "load_scene", payload: {scene}}', () {
    expect(const LoadScene(scene: 'ProductViewer').toJson(), {
      'type': 'load_scene',
      'payload': {'scene': 'ProductViewer'},
    });
  });

  test('round-trips via fromJson', () {
    final restored = FlunityMessage.fromJson(
      const LoadScene(scene: 'X').toJson(),
    );
    expect((restored as LoadScene).scene, 'X');
  });

  test('equality', () {
    expect(const LoadScene(scene: 'a'), const LoadScene(scene: 'a'));
    expect(const LoadScene(scene: 'a'), isNot(const LoadScene(scene: 'b')));
  });

  test('throws on missing scene', () {
    expect(
      () => FlunityMessage.fromJson({'type': 'load_scene', 'payload': {}}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

- [ ] **Step 2: Run, confirm fail.** Run: `flutter test test/messages/load_scene_test.dart`

- [ ] **Step 3: Implement `load_scene.dart`**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class LoadScene extends FlunityMessage {
  const LoadScene({required this.scene});

  static const String typeName = 'load_scene';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic s = payload['scene'];
      if (s is! String) {
        throw const FormatException('LoadScene payload requires string "scene"');
      }
      return LoadScene(scene: s);
    });
  }

  final String scene;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'scene': scene};

  @override
  bool operator ==(Object other) => other is LoadScene && other.scene == scene;

  @override
  int get hashCode => Object.hash('load_scene', scene);
}
```

- [ ] **Step 4: Run, confirm pass.** Expected: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/messages/load_scene.dart packages/flunity_bridge/test/messages/load_scene_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): LoadScene message"
```

### Task 14: `SceneReady` message (TDD)

**Files:**
- Create: `packages/flunity_bridge/lib/src/messages/scene_ready.dart`
- Create: `packages/flunity_bridge/test/messages/scene_ready_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SceneReady.register);

  test('serializes to {type: "scene_ready", payload: {}}', () {
    expect(const SceneReady().toJson(), {
      'type': 'scene_ready',
      'payload': <String, Object?>{},
    });
  });

  test('round-trips via fromJson', () {
    final restored = FlunityMessage.fromJson(const SceneReady().toJson());
    expect(restored, isA<SceneReady>());
  });

  test('all SceneReady instances are equal', () {
    expect(const SceneReady(), const SceneReady());
    expect(const SceneReady().hashCode, const SceneReady().hashCode);
  });
}
```

- [ ] **Step 2: Run, confirm fail.** Run: `flutter test test/messages/scene_ready_test.dart`

- [ ] **Step 3: Implement `scene_ready.dart`**

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class SceneReady extends FlunityMessage {
  const SceneReady();

  static const String typeName = 'scene_ready';

  static void register() {
    FlunityMessage.registerType(typeName, (_) => const SceneReady());
  }

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is SceneReady;

  @override
  int get hashCode => 'scene_ready'.hashCode;
}
```

- [ ] **Step 4: Run, confirm pass.** Expected: `+3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/messages/scene_ready.dart packages/flunity_bridge/test/messages/scene_ready_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): SceneReady message"
```

### Task 15: Built-in registration bootstrap

**Files:**
- Create: `packages/flunity_bridge/lib/src/messages/built_in.dart`
- Modify: `packages/flunity_bridge/test/flunity_message_test.dart`

- [ ] **Step 1: Write `built_in.dart`**

```dart
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';

/// Registers all built-in [FlunityMessage] subclasses with the parser registry.
/// Called automatically when `package:flunity_bridge/flunity_bridge.dart` is
/// imported (see `lib/flunity_bridge.dart`). Safe to call repeatedly.
void registerBuiltInMessages() {
  Ping.register();
  Pong.register();
  LoadScene.register();
  SceneReady.register();
}
```

- [ ] **Step 2: Add a test that all built-ins parse without explicit per-type setUp**

Append to `packages/flunity_bridge/test/flunity_message_test.dart`:

```dart
import 'package:flunity_bridge/src/messages/built_in.dart';
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';

// (existing imports preserved; only NEW group below — keep the original group too)

void registerAllForTest() => registerBuiltInMessages();

// Add inside main() — alongside existing groups, NOT replacing them:
//
//   group('built-in registration', () {
//     setUp(registerAllForTest);
//     test('Ping/Pong/LoadScene/SceneReady all parse via fromJson', () {
//       expect(FlunityMessage.fromJson(const Ping(nonce: 'a').toJson()), isA<Ping>());
//       expect(FlunityMessage.fromJson(const Pong(nonce: 'a').toJson()), isA<Pong>());
//       expect(FlunityMessage.fromJson(const LoadScene(scene: 's').toJson()), isA<LoadScene>());
//       expect(FlunityMessage.fromJson(const SceneReady().toJson()), isA<SceneReady>());
//     });
//
//     test('unknown type still falls back to RawMessage', () {
//       final msg = FlunityMessage.fromJson({'type': 'who_dis', 'payload': {}});
//       expect(msg, isA<RawMessage>());
//     });
//   });
```

The actual file after the edit (full replacement to avoid ambiguity):

```dart
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/built_in.dart';
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawMessage', () {
    test('serializes to {type, payload} envelope', () {
      const msg = RawMessage(type: 'custom', payload: {'a': 1});
      expect(msg.toJson(), {'type': 'custom', 'payload': {'a': 1}});
    });

    test('round-trips via fromJson', () {
      const original = RawMessage(type: 'custom', payload: {'a': 1});
      final restored = FlunityMessage.fromJson(original.toJson());
      expect(restored, isA<RawMessage>());
      final raw = restored as RawMessage;
      expect(raw.type, 'custom');
      expect(raw.payload, {'a': 1});
    });

    test('fromJson throws FormatException when type is missing', () {
      expect(
        () => FlunityMessage.fromJson({'payload': {}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson tolerates missing payload as empty map', () {
      final msg = FlunityMessage.fromJson({'type': 'noop'}) as RawMessage;
      expect(msg.payload, <String, Object?>{});
    });
  });

  group('built-in registration', () {
    setUp(registerBuiltInMessages);

    test('Ping/Pong/LoadScene/SceneReady all parse via fromJson', () {
      expect(FlunityMessage.fromJson(const Ping(nonce: 'a').toJson()), isA<Ping>());
      expect(FlunityMessage.fromJson(const Pong(nonce: 'a').toJson()), isA<Pong>());
      expect(FlunityMessage.fromJson(const LoadScene(scene: 's').toJson()), isA<LoadScene>());
      expect(FlunityMessage.fromJson(const SceneReady().toJson()), isA<SceneReady>());
    });

    test('unknown type still falls back to RawMessage', () {
      final msg = FlunityMessage.fromJson({'type': 'who_dis', 'payload': {}});
      expect(msg, isA<RawMessage>());
    });
  });
}
```

- [ ] **Step 3: Run all tests in the package**

Run: `cd packages/flunity_bridge && flutter test`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/messages/built_in.dart packages/flunity_bridge/test/flunity_message_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): built-in message registration"
```

---

## Phase 5 — `FlunityWebGLConfig`

### Task 16: Config dev/bundled factories (TDD)

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_webgl_config.dart`
- Create: `packages/flunity_bridge/test/flunity_webgl_config_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
      const c = FlunityWebGLConfig.bundled();
      expect(c.mode, FlunityWebGLMode.bundled);
      expect(c.assetPath, 'assets/unity_webgl/');
    });

    test('normalizes assetPath to a trailing slash', () {
      expect(
        const FlunityWebGLConfig.bundled(assetPath: 'assets/foo').assetPath,
        'assets/foo/',
      );
    });
  });
}
```

- [ ] **Step 2: Run, confirm fail.** Run: `flutter test test/flunity_webgl_config_test.dart`

- [ ] **Step 3: Implement `flunity_webgl_config.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

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
```

- [ ] **Step 4: Run, confirm pass.** Expected: `+7: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/flunity_webgl_config.dart packages/flunity_bridge/test/flunity_webgl_config_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): FlunityWebGLConfig dev/bundled with Android loopback swap"
```

---

## Phase 6 — Transport abstraction

### Task 17: `MessageTransport` interface + `FakeMessageTransport`

**Files:**
- Create: `packages/flunity_bridge/lib/src/transport/message_transport.dart`
- Create: `packages/flunity_bridge/test/transport/fake_transport.dart`

- [ ] **Step 1: Write `message_transport.dart`**

```dart
/// Abstract transport for the Flutter <-> Unity bridge. Implementations:
///   - InAppWebViewMessageTransport: real WebView (lib/src/transport/inapp_webview_transport.dart)
///   - FakeMessageTransport: in-memory test impl (test/transport/fake_transport.dart)
abstract interface class MessageTransport {
  /// A future that completes when the underlying runtime is ready to accept messages.
  Future<void> get ready;

  /// Stream of raw JSON strings sent from Unity to Flutter.
  Stream<String> get incoming;

  /// Send a JSON string from Flutter to Unity. Implementations queue if not yet ready.
  Future<void> send(String json);

  /// Reload the underlying runtime (e.g. WebView reload). Optional for fakes.
  Future<void> reload();

  /// Tear down resources. Idempotent.
  Future<void> dispose();
}
```

- [ ] **Step 2: Write `fake_transport.dart`** (test helper, lives under `test/`)

```dart
import 'dart:async';

import 'package:flunity_bridge/src/transport/message_transport.dart';

/// Test double for [MessageTransport]. Tests drive `incoming` via [pushFromUnity]
/// and assert what was sent via [sentMessages].
class FakeMessageTransport implements MessageTransport {
  FakeMessageTransport({bool startReady = true}) {
    if (startReady) markReady();
  }

  final List<String> sentMessages = <String>[];
  final StreamController<String> _incoming = StreamController<String>.broadcast();
  final Completer<void> _ready = Completer<void>();
  bool _disposed = false;
  int reloadCount = 0;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Future<void> send(String json) async {
    if (_disposed) throw StateError('FakeMessageTransport disposed');
    await ready;
    sentMessages.add(json);
  }

  @override
  Future<void> reload() async {
    reloadCount += 1;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _incoming.close();
  }

  // Test helpers ---

  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void pushFromUnity(String json) {
    _incoming.add(json);
  }
}
```

- [ ] **Step 3: Verify analyzer is clean**

Run: `cd packages/flunity_bridge && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/transport packages/flunity_bridge/test/transport
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): MessageTransport interface + FakeMessageTransport"
```

---

## Phase 7 — `FlunityWebGLController`

### Task 18: Controller behavior — TDD

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_webgl_controller.dart`
- Create: `packages/flunity_bridge/test/flunity_webgl_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/flunity_webgl_controller.dart';
import 'package:flunity_bridge/src/messages/built_in.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transport/fake_transport.dart';

void main() {
  setUp(registerBuiltInMessages);

  test('send() before ready queues, then flushes once ready', () async {
    final transport = FakeMessageTransport(startReady: false);
    final controller = FlunityWebGLController(transport: transport);

    final pending = controller.send(const Ping(nonce: 'q'));
    expect(transport.sentMessages, isEmpty);

    transport.markReady();
    await pending;

    expect(transport.sentMessages, hasLength(1));
    final decoded = jsonDecode(transport.sentMessages.first) as Map<String, Object?>;
    expect(decoded['type'], 'ping');
    expect(decoded['payload'], {'nonce': 'q'});
  });

  test('messages stream emits typed FlunityMessage values', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(transport: transport);

    final received = <FlunityMessage>[];
    final sub = controller.messages.listen(received.add);

    transport.pushFromUnity(jsonEncode(const Pong(nonce: 'r').toJson()));
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single, isA<Pong>());
    expect((received.single as Pong).nonce, 'r');

    await sub.cancel();
    await controller.dispose();
  });

  test('messages stream surfaces malformed JSON via onError handler', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(transport: transport);

    final errors = <Object>[];
    final sub = controller.messages.listen((_) {}, onError: errors.add);

    transport.pushFromUnity('{not valid json');
    await Future<void>.delayed(Duration.zero);

    expect(errors, hasLength(1));
    await sub.cancel();
    await controller.dispose();
  });

  test('isReady reflects underlying transport readiness', () async {
    final transport = FakeMessageTransport(startReady: false);
    final controller = FlunityWebGLController(transport: transport);

    expect(controller.isReady, isFalse);
    transport.markReady();
    await transport.ready;
    expect(controller.isReady, isTrue);
  });

  test('reload delegates to transport', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(transport: transport);
    await controller.reload();
    expect(transport.reloadCount, 1);
  });

  test('dispose closes the messages stream', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(transport: transport);

    final done = controller.messages.toList();
    await controller.dispose();
    expect(await done, isEmpty);
  });
}
```

- [ ] **Step 2: Run, confirm fail.** Run: `flutter test test/flunity_webgl_controller_test.dart`

- [ ] **Step 3: Implement `flunity_webgl_controller.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/transport/message_transport.dart';

/// High-level Flutter-side controller. Wraps a [MessageTransport] and
/// exposes typed [FlunityMessage] streams + send.
class FlunityWebGLController {
  FlunityWebGLController({required MessageTransport transport})
      : _transport = transport {
    _transport.ready.then((_) {
      _isReady = true;
    });
    _incomingSub = _transport.incoming.listen(
      _handleIncoming,
      onError: _messages.addError,
    );
  }

  final MessageTransport _transport;
  final StreamController<FlunityMessage> _messages =
      StreamController<FlunityMessage>.broadcast();
  late final StreamSubscription<String> _incomingSub;

  bool _isReady = false;
  bool _disposed = false;

  bool get isReady => _isReady;

  Stream<FlunityMessage> get messages => _messages.stream;

  Future<void> send(FlunityMessage message) async {
    if (_disposed) {
      throw StateError('FlunityWebGLController has been disposed');
    }
    final encoded = jsonEncode(message.toJson());
    return _transport.send(encoded);
  }

  Future<void> reload() => _transport.reload();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _incomingSub.cancel();
    await _transport.dispose();
    await _messages.close();
  }

  void _handleIncoming(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) {
        _messages.addError(
          FormatException('Expected JSON object from Unity, got ${decoded.runtimeType}'),
        );
        return;
      }
      _messages.add(FlunityMessage.fromJson(decoded));
    } on FormatException catch (e, st) {
      _messages.addError(e, st);
    }
  }
}
```

- [ ] **Step 4: Run, confirm pass.** Expected: `+6: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/flunity_webgl_controller.dart packages/flunity_bridge/test/flunity_webgl_controller_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): FlunityWebGLController with queueing + typed stream"
```

---

## Phase 8 — Real `flutter_inappwebview` transport + view widget

These two files glue our package to `flutter_inappwebview`. They're not unit-tested in this plan (the platform view doesn't widget-test cleanly without a real device); they're exercised by Plan C's example smoke test on a stub WebGL build.

### Task 19: `InAppWebViewMessageTransport`

**Files:**
- Create: `packages/flunity_bridge/lib/src/transport/inapp_webview_transport.dart`

- [ ] **Step 1: Implement the transport**

```dart
import 'dart:async';
import 'dart:collection';

import 'package:flunity_bridge/src/transport/message_transport.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// [MessageTransport] backed by an [InAppWebViewController]. Routes outbound
/// JSON via `window.flunity.post(...)` (defined by the JS shim) and surfaces
/// inbound JSON via the `flunity` JS handler.
class InAppWebViewMessageTransport implements MessageTransport {
  InAppWebViewMessageTransport();

  InAppWebViewController? _webViewController;
  final Completer<void> _ready = Completer<void>();
  final StreamController<String> _incoming = StreamController<String>.broadcast();
  final Queue<String> _pending = Queue<String>();
  bool _disposed = false;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Future<void> send(String json) async {
    if (_disposed) throw StateError('InAppWebViewMessageTransport disposed');
    if (_webViewController == null || !_ready.isCompleted) {
      _pending.add(json);
      return;
    }
    await _evaluate(json);
  }

  @override
  Future<void> reload() async {
    await _webViewController?.reload();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    await _incoming.close();
    _webViewController = null;
  }

  /// Hooked by [FlunityWebGLView] when the platform controller is available.
  void attach(InAppWebViewController controller) {
    _webViewController = controller;
    controller.addJavaScriptHandler(
      handlerName: 'flunity',
      callback: (args) {
        if (_disposed) return null;
        if (args.isNotEmpty && args.first is String) {
          _incoming.add(args.first as String);
        }
        return null;
      },
    );
  }

  /// Hooked by [FlunityWebGLView] once `window.flunity.ready()` fires.
  Future<void> markReady() async {
    if (_disposed || _ready.isCompleted) return;
    _ready.complete();
    while (_pending.isNotEmpty) {
      final next = _pending.removeFirst();
      await _evaluate(next);
    }
  }

  Future<void> _evaluate(String json) async {
    final controller = _webViewController;
    if (controller == null) return;
    final escaped = _jsString(json);
    await controller.evaluateJavascript(source: 'window.flunity.post($escaped);');
  }

  static String _jsString(String value) {
    final buf = StringBuffer('"');
    for (final r in value.runes) {
      final ch = String.fromCharCode(r);
      switch (ch) {
        case '\\': buf.write(r'\\'); break;
        case '"':  buf.write(r'\"'); break;
        case '\n': buf.write(r'\n'); break;
        case '\r': buf.write(r'\r'); break;
        case '\t': buf.write(r'\t'); break;
        default:
          if (r < 0x20) {
            buf.write('\\u${r.toRadixString(16).padLeft(4, '0')}');
          } else {
            buf.write(ch);
          }
      }
    }
    buf.write('"');
    return buf.toString();
  }
}
```

- [ ] **Step 2: Verify analyzer is clean**

Run: `cd packages/flunity_bridge && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/transport/inapp_webview_transport.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): InAppWebViewMessageTransport"
```

### Task 20: `FlunityWebGLView` widget

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_webgl_view.dart`

- [ ] **Step 1: Implement the view**

```dart
import 'package:flunity_bridge/src/flunity_webgl_config.dart';
import 'package:flunity_bridge/src/flunity_webgl_controller.dart';
import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/transport/inapp_webview_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Drop-in widget that loads a Unity WebGL build inside an [InAppWebView] and
/// exposes a typed [FlunityWebGLController] via [onReady].
///
/// Bundled mode uses an [InAppLocalhostServer] because Unity WebGL refuses to
/// load via `file://` (uses ranged requests + workers). The server is started
/// lazily on first mount and reused process-wide.
class FlunityWebGLView extends StatefulWidget {
  const FlunityWebGLView({
    required this.config,
    this.onReady,
    this.onMessage,
    this.loadingBuilder,
    this.errorBuilder,
    super.key,
  });

  final FlunityWebGLConfig config;
  final ValueChanged<FlunityWebGLController>? onReady;
  final ValueChanged<FlunityMessage>? onMessage;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext, Object error)? errorBuilder;

  @override
  State<FlunityWebGLView> createState() => _FlunityWebGLViewState();
}

class _FlunityWebGLViewState extends State<FlunityWebGLView> {
  static final InAppLocalhostServer _bundledServer =
      InAppLocalhostServer(documentRoot: 'assets');

  late final InAppWebViewMessageTransport _transport;
  FlunityWebGLController? _controller;
  Object? _error;
  bool _bundledServerStarted = false;

  @override
  void initState() {
    super.initState();
    _transport = InAppWebViewMessageTransport();
    _controller = FlunityWebGLController(transport: _transport);
    if (widget.onReady != null) {
      // Fire onReady immediately; consumers can call send() — it'll queue.
      widget.onReady!(_controller!);
    }
    _controller!.messages.listen((m) => widget.onMessage?.call(m));
    _ensureBundledServerIfNeeded();
  }

  Future<void> _ensureBundledServerIfNeeded() async {
    if (widget.config.mode != FlunityWebGLMode.bundled) return;
    if (_bundledServer.isRunning()) {
      _bundledServerStarted = true;
      if (mounted) setState(() {});
      return;
    }
    try {
      await _bundledServer.start();
      _bundledServerStarted = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  WebUri _initialUri() {
    if (widget.config.mode == FlunityWebGLMode.dev) {
      final base = widget.config.resolveBaseUrl(platform: defaultTargetPlatform);
      return WebUri('${base}index.html');
    }
    // Bundled: InAppLocalhostServer's documentRoot is 'assets', so URLs are
    // relative to the Flutter assets root. Strip the leading 'assets/' from
    // the project-relative assetPath when building the URL.
    final urlPath = widget.config.assetPath.startsWith('assets/')
        ? widget.config.assetPath.substring('assets/'.length)
        : widget.config.assetPath;
    return WebUri('http://localhost:8080/${urlPath}index.html');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final builder = widget.errorBuilder;
      return builder != null
          ? builder(context, _error!)
          : Center(child: Text('Flunity error: $_error'));
    }
    if (widget.config.mode == FlunityWebGLMode.bundled && !_bundledServerStarted) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: _initialUri()),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldInterceptAjaxRequest: false,
        transparentBackground: true,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        _transport.attach(controller);
      },
      onLoadStop: (controller, url) async {
        // Wait for window.flunity.ready() to be called by the JS shim.
        await controller.evaluateJavascript(source: '''
          if (window.flunity && window.flunity._isReady) {
            window.flutter_inappwebview.callHandler('flunity_ready');
          } else {
            (window.flunity ||= {})._notifyReady = function() {
              window.flutter_inappwebview.callHandler('flunity_ready');
            };
          }
        ''');
      },
    );
  }
}
```

Note: the `flunity_ready` handler is registered by the transport's JS-shim glue inside `bridge init` (Plan B/C); for now this view file only needs to compile and load. The shim is responsible for triggering ready.

- [ ] **Step 2: Wire the `flunity_ready` handler in the transport**

Modify: `packages/flunity_bridge/lib/src/transport/inapp_webview_transport.dart`

In `attach()`, register a second handler so the shim can mark us ready:

```dart
controller.addJavaScriptHandler(
  handlerName: 'flunity_ready',
  callback: (_) {
    markReady();
    return null;
  },
);
```

Place this immediately after the existing `flunity` handler registration.

- [ ] **Step 3: Verify analyzer is clean**

Run: `cd packages/flunity_bridge && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/flunity_webgl_view.dart packages/flunity_bridge/lib/src/transport/inapp_webview_transport.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): FlunityWebGLView widget + flunity_ready handler"
```

---

## Phase 9 — Public API exports + green run

### Task 21: Public exports

**Files:**
- Modify: `packages/flunity_bridge/lib/flunity_bridge.dart`

- [ ] **Step 1: Replace contents**

```dart
/// Flunity bridge: embed Unity WebGL inside Flutter with a typed message bridge.
///
/// Consumers must call [registerBuiltInMessages] once at app startup (typically
/// in `main()`) before any [FlunityMessage.fromJson] calls. Plan C's templates
/// do this for generated apps. Direct consumers should call it themselves —
/// see the package README for an example.
library flunity_bridge;

export 'package:flunity_bridge/src/flunity_message.dart';
export 'package:flunity_bridge/src/messages/built_in.dart' show registerBuiltInMessages;
export 'package:flunity_bridge/src/messages/load_scene.dart';
export 'package:flunity_bridge/src/messages/ping.dart';
export 'package:flunity_bridge/src/messages/pong.dart';
export 'package:flunity_bridge/src/messages/scene_ready.dart';
export 'package:flunity_bridge/src/flunity_webgl_config.dart';
export 'package:flunity_bridge/src/flunity_webgl_controller.dart';
export 'package:flunity_bridge/src/flunity_webgl_view.dart';
export 'package:flunity_bridge/src/transport/message_transport.dart';
```

- [ ] **Step 2: Update README.md to document the registration step**

Modify: `packages/flunity_bridge/README.md`

Replace the Quickstart code block with:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

void main() {
  registerBuiltInMessages(); // <-- call once at startup
  runApp(const MyApp());
}

// Inside a screen:
FlunityWebGLView(
  config: const FlunityWebGLConfig.dev(port: 8080),
  onReady: (controller) {
    controller.send(const Ping(nonce: 'hello'));
  },
  onMessage: (msg) {
    if (msg is Pong) print('Got pong: ${msg.nonce}');
  },
);
```

- [ ] **Step 3: Add a smoke test that the public surface works**

Create: `packages/flunity_bridge/test/public_api_test.dart`

```dart
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public API: registerBuiltInMessages enables typed parsing', () {
    registerBuiltInMessages();
    final restored = FlunityMessage.fromJson(const Ping(nonce: 'ok').toJson());
    expect(restored, isA<Ping>());
  });

  test('public API: FlunityWebGLConfig.bundled exported', () {
    expect(const FlunityWebGLConfig.bundled().assetPath, 'assets/unity_webgl/');
  });
}
```

- [ ] **Step 4: Run the full bridge test suite**

Run: `cd packages/flunity_bridge && flutter test`
Expected: all tests pass; final summary shows N tests across files.

- [ ] **Step 5: Run analyze across the workspace**

Run from repo root: `melos run analyze`
Expected: `No issues found!` for every package.

- [ ] **Step 6: Run melos test across the workspace**

Run from repo root: `melos run test`
Expected: every package's tests pass.

- [ ] **Step 7: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/flunity_bridge.dart packages/flunity_bridge/README.md packages/flunity_bridge/test/public_api_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): public exports + explicit registerBuiltInMessages"
```

---

## Phase 10 — Wrap up

### Task 22: Add CI workflow stub

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  bridge:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: dart pub global activate melos
      - run: melos bootstrap
      - run: melos run format-check
      - run: melos run analyze
      - run: melos run test
```

### Task 23: Push and close out

- [ ] **Step 1: Run all checks one last time**

Run: `melos run format-check && melos run analyze && melos run test`
Expected: all green.

- [ ] **Step 2: Commit CI**

```bash
git -C /Volumes/Transcend/Projects/flunity add .github/workflows/ci.yml
git -C /Volumes/Transcend/Projects/flunity commit -m "ci: add melos-driven CI workflow"
```

- [ ] **Step 3: Push to origin**

```bash
git -C /Volumes/Transcend/Projects/flunity push origin main
```

Expected: `main` advances on `origin`.

- [ ] **Step 4: Verify on GitHub**

Manually check that the CI workflow runs and goes green.

---

## Definition of done for Plan A

- [ ] `melos bootstrap` succeeds from the repo root.
- [ ] `melos run analyze` reports `No issues found!` across the workspace.
- [ ] `melos run test` passes; `flunity_bridge` has tests for messages, config, controller queueing, controller stream parsing, controller dispose, and public API.
- [ ] `packages/flunity_bridge/lib/flunity_bridge.dart` exports the full intended public surface.
- [ ] `FlunityWebGLView` compiles and analyzes; widget-level testing deferred to Plan C smoke test.
- [ ] Repo on `origin/main` is green in CI.

When done, brainstorm Plan B (CLI) — the implementation work in Plan A may have surfaced details (e.g. controller initialization order) that affect the templates the CLI generates.
