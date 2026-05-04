# Plan B — `flunity_cli` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the `flunity_cli` Dart package — the `flunity` executable (with `fl` and `fu` aliases) — implementing all five v1 commands (`create`, `doctor`, `webgl serve`, `webgl copy` + `webgl clean`, `bridge init`) plus the `flunity.yaml` manifest model and a template-rendering engine. Polish the repo + package READMEs with a step-by-step "How to use Flunity" walkthrough.

**Architecture:** Pure-Dart CLI built on `args` (CommandRunner). `FlunityProject` owns manifest loading + path resolution; commands consume it. `TemplateRenderer` substitutes `__var__` placeholders during `flunity create`. `webgl serve` is a `shelf_static` server with Unity-correct MIME types and COOP/COEP headers. Codegen-style commands (`bridge init`) refuse to clobber user files unless `--force`. The `executables:` section of `pubspec.yaml` declares three aliases — `flunity`, `fl`, `fu` — all dispatching to `bin/flunity.dart`.

**Tech Stack:** Dart `^3.5.0`, `args ^2.5.0`, `mason_logger ^0.3.0`, `path ^1.9.0`, `yaml ^3.1.2`, `pub_semver ^2.1.4`, `shelf ^1.4.0`, `shelf_static ^1.1.2`, `http_multi_server ^3.2.1`. Path-dep on `flunity_bridge` to read its current version (used during `bridge init` and `create` template rendering).

**Spec reference:** `docs/superpowers/specs/2026-05-04-flunity-v1-design.md` §3, §4, §5. Plan A's deliverable (`flunity_bridge`) is already merged on `main`.

---

## Prerequisites

- Branch `feat/plan-b-cli` (already cut from `main` at the merged Plan A tip).
- Plan A's CI is green; `flunity_bridge` package is on `main`.
- `melos bootstrap` from repo root has been run.

---

## File Structure

```
flunity/
├── packages/
│   └── flunity_cli/
│       ├── pubspec.yaml
│       ├── analysis_options.yaml
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── bin/
│       │   └── flunity.dart                       # `dart run` entrypoint, calls runFlunityCli
│       ├── lib/
│       │   ├── flunity_cli.dart                   # public exports (mainly for testing)
│       │   └── src/
│       │       ├── runner.dart                    # CommandRunner setup + runFlunityCli()
│       │       ├── manifest/
│       │       │   ├── flunity_project.dart       # FlunityProject typed model
│       │       │   ├── manifest_schema.dart       # parses flunity.yaml → FlunityProject
│       │       │   └── manifest_finder.dart       # walks up to find flunity.yaml
│       │       ├── templates/
│       │       │   ├── template_renderer.dart     # __var__ substitution + tree copy
│       │       │   └── template_vars.dart         # standard variables (app_name, etc.)
│       │       ├── webgl/
│       │       │   ├── dev_server.dart            # shelf-based static server with Unity MIME
│       │       │   ├── unity_mime.dart            # MIME map + brotli/gzip handler
│       │       │   └── webgl_copy.dart            # build-dir → assets/ copy + manifest hash
│       │       ├── bridge/
│       │       │   ├── bridge_init.dart           # add flunity_bridge dep, copy unity/ files
│       │       │   └── index_html_patcher.dart    # idempotent patcher for Unity index.html
│       │       ├── doctor/
│       │       │   ├── doctor.dart                # orchestrates checks
│       │       │   ├── check.dart                 # Check abstract + CheckResult
│       │       │   └── checks/                    # individual check classes
│       │       │       ├── flutter_sdk_check.dart
│       │       │       ├── dart_sdk_check.dart
│       │       │       ├── manifest_present_check.dart
│       │       │       ├── unity_project_check.dart
│       │       │       ├── unity_build_check.dart
│       │       │       ├── flutter_assets_declared_check.dart
│       │       │       └── port_available_check.dart
│       │       ├── commands/
│       │       │   ├── create_command.dart        # `flunity create <name>`
│       │       │   ├── doctor_command.dart        # `flunity doctor`
│       │       │   ├── webgl_command.dart         # `flunity webgl <serve|copy|clean>` (parent)
│       │       │   └── bridge_command.dart        # `flunity bridge <init>` (parent)
│       │       └── utils/
│       │           ├── process_runner.dart        # thin wrapper around dart:io Process
│       │           ├── file_utils.dart            # safe copy, ensureDir, etc.
│       │           └── pubspec_editor.dart        # add a dep to a pubspec.yaml safely
│       ├── templates/
│       │   ├── flutter_webgl_basic/               # default for create --no-bridge
│       │   └── flutter_webgl_bridge/              # default for create
│       │       └── ...                            # full template tree (Plan C polishes content)
│       └── test/
│           ├── manifest/
│           │   ├── flunity_project_test.dart
│           │   └── manifest_finder_test.dart
│           ├── templates/
│           │   └── template_renderer_test.dart
│           ├── webgl/
│           │   ├── dev_server_test.dart
│           │   ├── unity_mime_test.dart
│           │   └── webgl_copy_test.dart
│           ├── bridge/
│           │   ├── bridge_init_test.dart
│           │   └── index_html_patcher_test.dart
│           ├── doctor/
│           │   ├── doctor_test.dart
│           │   └── checks_test.dart
│           ├── commands/
│           │   ├── create_command_test.dart
│           │   └── webgl_clean_command_test.dart
│           └── runner_test.dart                   # exercises argument parsing
└── (existing repo files unchanged)
```

The `templates/` content under `flunity_cli/` is intentionally minimal in Plan B — just enough to make `flunity create` produce a valid Flutter app + manifest + scripts skeleton. Plan C fills in real WebView screens, demo bridge wiring, and Unity-side scripts.

---

## Phase 1 — `flunity_cli` package skeleton

### Task 1: Create package directory + pubspec

**Files:**
- Create: `packages/flunity_cli/pubspec.yaml`
- Create: `packages/flunity_cli/analysis_options.yaml`
- Create: `packages/flunity_cli/README.md`
- Create: `packages/flunity_cli/CHANGELOG.md`
- Create: `packages/flunity_cli/lib/flunity_cli.dart`
- Create: `packages/flunity_cli/bin/flunity.dart`

- [ ] **Step 1: Write `pubspec.yaml`**

```yaml
name: flunity_cli
description: The flunity command — scaffold, serve, and bundle Flutter + Unity WebGL projects.
version: 0.1.0
homepage: https://github.com/RubenNunez/flunity
repository: https://github.com/RubenNunez/flunity
issue_tracker: https://github.com/RubenNunez/flunity/issues

environment:
  sdk: ^3.5.0

executables:
  flunity:
  fl:
  fu:

dependencies:
  args: ^2.5.0
  http_multi_server: ^3.2.1
  mason_logger: ^0.3.0
  mime: ^1.0.5
  path: ^1.9.0
  pub_semver: ^2.1.4
  shelf: ^1.4.0
  shelf_static: ^1.1.2
  yaml: ^3.1.2

dev_dependencies:
  lints: ^4.0.0
  test: ^1.25.0
```

- [ ] **Step 2: Write `analysis_options.yaml`**

```yaml
include: ../../analysis_options.yaml

# CLI is pure Dart — relax Flutter-specific lints that don't apply.
analyzer:
  errors:
    avoid_print: ignore   # CLI explicitly prints to stdout
```

- [ ] **Step 3: Write `lib/flunity_cli.dart`**

```dart
/// The Flunity CLI library — primarily exposed for tests and downstream tooling.
/// End users should invoke the `flunity` executable instead.
library flunity_cli;

export 'package:flunity_cli/src/runner.dart' show runFlunityCli;
```

- [ ] **Step 4: Write `bin/flunity.dart`**

```dart
import 'dart:io';

import 'package:flunity_cli/src/runner.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runFlunityCli(args);
  exit(exitCode);
}
```

- [ ] **Step 5: Write `README.md`**

```markdown
# flunity_cli

The `flunity` command — a development companion for Flutter + Unity WebGL projects.

## Install

```bash
dart pub global activate flunity_cli
```

This installs three command names that all run the same binary:

| Command | Purpose |
| --- | --- |
| `flunity` | canonical name — use in scripts and CI |
| `fl` | short alias for everyday typing |
| `fu` | short alias for everyday typing |

Make sure `$HOME/.pub-cache/bin` is on your PATH.

## How to use Flunity (end-to-end)

The full how-to lives in the [main repo README](../../README.md#how-to). The short version:

```bash
fl create my_app                # scaffold
fl doctor                       # verify environment
# (open my_app/unity_project in Unity; build WebGL to unity_project/Builds/WebGL/)
fl webgl serve                  # local dev server
cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev
# for production:
fl webgl copy
flutter build apk
```

## License

MIT.
```

- [ ] **Step 6: Write `CHANGELOG.md`**

```markdown
# Changelog

## [Unreleased]

### Added
- Initial release: `create`, `doctor`, `webgl serve`, `webgl copy`, `webgl clean`, and `bridge init` commands.
- `flunity.yaml` project manifest model and loader.
- Template rendering engine (`__var__` substitution).
- Three executable aliases: `flunity`, `fl`, `fu`.
```

### Task 2: Stub `runner.dart` so the executable runs

**Files:**
- Create: `packages/flunity_cli/lib/src/runner.dart`

- [ ] **Step 1: Write a minimal runner that prints the version**

```dart
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

const String flunityVersion = '0.1.0';

Future<int> runFlunityCli(List<String> args, {Logger? logger}) async {
  final log = logger ?? Logger();
  final runner = CommandRunner<int>(
    'flunity',
    'Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.',
  )..argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the flunity version.',
    );

  // Commands wired in later phases. For now just version + --help.
  try {
    final results = runner.argParser.parse(args);
    if (results['version'] == true) {
      log.info('flunity $flunityVersion');
      return 0;
    }
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    log.err(e.toString());
    return 64;
  }
}
```

### Task 3: Bootstrap, analyze, smoke-run, commit

- [ ] **Step 1: Bootstrap workspace**

Run from repo root: `cd /Volumes/Transcend/Projects/flunity && melos bootstrap`
Expected: 2 packages bootstrapped (flunity_bridge + flunity_cli).

- [ ] **Step 2: Analyze**

Run: `cd packages/flunity_cli && dart analyze`
Expected: `No issues found!`

- [ ] **Step 3: Smoke-run the executable**

Run: `cd packages/flunity_cli && dart run bin/flunity.dart --version`
Expected: prints `flunity 0.1.0` and exits 0.

- [ ] **Step 4: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): package skeleton with three executable aliases"
```

---

## Phase 2 — `FlunityProject` manifest model

### Task 4: Schema + loader (TDD)

**Files:**
- Create: `packages/flunity_cli/lib/src/manifest/flunity_project.dart`
- Create: `packages/flunity_cli/lib/src/manifest/manifest_schema.dart`
- Create: `packages/flunity_cli/test/manifest/flunity_project_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/flunity_cli/test/manifest/flunity_project_test.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('parses a complete manifest', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: my_app
version: 0.1.0
target: webgl
paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_build: unity_project/Builds/WebGL
  flutter_assets: flutter_app/assets/unity_webgl
webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false
  android_emulator_host: 10.0.2.2
bridge:
  enabled: true
  messages: []
''');

    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));

    expect(project.name, 'my_app');
    expect(project.version, '0.1.0');
    expect(project.target, FlunityTarget.webgl);
    expect(project.paths.flutterApp, p.join(tmp.path, 'flutter_app'));
    expect(project.paths.unityProject, p.join(tmp.path, 'unity_project'));
    expect(project.paths.unityBuild, p.join(tmp.path, 'unity_project/Builds/WebGL'));
    expect(project.paths.flutterAssets, p.join(tmp.path, 'flutter_app/assets/unity_webgl'));
    expect(project.webgl.devServer.host, '127.0.0.1');
    expect(project.webgl.devServer.port, 8080);
    expect(project.webgl.devServer.crossOriginIsolation, true);
    expect(project.webgl.devServer.hotReload, false);
    expect(project.webgl.androidEmulatorHost, '10.0.2.2');
    expect(project.bridge.enabled, true);
  });

  test('applies sensible defaults to a minimal manifest', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: minimal
target: webgl
''');

    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));

    expect(project.paths.flutterApp, p.join(tmp.path, 'flutter_app'));
    expect(project.paths.unityProject, p.join(tmp.path, 'unity_project'));
    expect(project.webgl.devServer.host, '127.0.0.1');
    expect(project.webgl.devServer.port, 8080);
    expect(project.bridge.enabled, true);
  });

  test('rejects unknown target with a friendly error', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: oops
target: native_android
''');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.message,
          'message',
          contains('native_android'),
        ),
      ),
    );
  });

  test('rejects manifest with missing name', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('target: webgl');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(isA<ManifestException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to confirm fail**

Run: `cd /Volumes/Transcend/Projects/flunity/packages/flunity_cli && dart test test/manifest/flunity_project_test.dart`
Expected: import error.

- [ ] **Step 3: Implement `flunity_project.dart`**

```dart
import 'package:path/path.dart' as p;

import 'manifest_schema.dart';

enum FlunityTarget { webgl }

class FlunityProject {
  FlunityProject({
    required this.rootDir,
    required this.name,
    required this.version,
    required this.target,
    required this.paths,
    required this.webgl,
    required this.bridge,
  });

  final String rootDir;
  final String name;
  final String version;
  final FlunityTarget target;
  final FlunityPaths paths;
  final FlunityWebGLSettings webgl;
  final FlunityBridgeSettings bridge;

  static FlunityProject loadFromManifest(String manifestPath) {
    return parseManifest(manifestPath);
  }

  String get manifestPath => p.join(rootDir, 'flunity.yaml');
}

class FlunityPaths {
  FlunityPaths({
    required this.flutterApp,
    required this.unityProject,
    required this.unityBuild,
    required this.flutterAssets,
  });

  final String flutterApp;
  final String unityProject;
  final String unityBuild;
  final String flutterAssets;
}

class FlunityWebGLSettings {
  FlunityWebGLSettings({
    required this.devServer,
    required this.androidEmulatorHost,
  });

  final FlunityDevServerSettings devServer;
  final String androidEmulatorHost;
}

class FlunityDevServerSettings {
  FlunityDevServerSettings({
    required this.host,
    required this.port,
    required this.crossOriginIsolation,
    required this.hotReload,
  });

  final String host;
  final int port;
  final bool crossOriginIsolation;
  final bool hotReload;
}

class FlunityBridgeSettings {
  FlunityBridgeSettings({required this.enabled, required this.messages});

  final bool enabled;
  final List<String> messages;
}
```

- [ ] **Step 4: Implement `manifest_schema.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'flunity_project.dart';

class ManifestException implements Exception {
  ManifestException(this.message);
  final String message;
  @override
  String toString() => 'ManifestException: $message';
}

FlunityProject parseManifest(String manifestPath) {
  final file = File(manifestPath);
  if (!file.existsSync()) {
    throw ManifestException('Manifest not found: $manifestPath');
  }
  final rootDir = p.dirname(file.absolute.path);
  final dynamic doc = loadYaml(file.readAsStringSync());
  if (doc is! YamlMap) {
    throw ManifestException('Manifest must be a YAML map at top level.');
  }

  final name = _requireString(doc, 'name');
  final version = _optionalString(doc, 'version') ?? '0.1.0';
  final targetStr = _requireString(doc, 'target');
  final target = switch (targetStr) {
    'webgl' => FlunityTarget.webgl,
    _ => throw ManifestException(
        'Unknown target "$targetStr" — only "webgl" is supported in v1.',
      ),
  };

  final pathsMap = doc['paths'] as YamlMap?;
  final paths = FlunityPaths(
    flutterApp: _resolvePath(rootDir, pathsMap, 'flutter_app', 'flutter_app'),
    unityProject:
        _resolvePath(rootDir, pathsMap, 'unity_project', 'unity_project'),
    unityBuild: _resolvePath(
        rootDir, pathsMap, 'unity_build', 'unity_project/Builds/WebGL'),
    flutterAssets: _resolvePath(
        rootDir, pathsMap, 'flutter_assets', 'flutter_app/assets/unity_webgl'),
  );

  final webglMap = doc['webgl'] as YamlMap?;
  final devServerMap = webglMap?['dev_server'] as YamlMap?;
  final webgl = FlunityWebGLSettings(
    devServer: FlunityDevServerSettings(
      host: (devServerMap?['host'] as String?) ?? '127.0.0.1',
      port: (devServerMap?['port'] as int?) ?? 8080,
      crossOriginIsolation:
          (devServerMap?['cross_origin_isolation'] as bool?) ?? true,
      hotReload: (devServerMap?['hot_reload'] as bool?) ?? false,
    ),
    androidEmulatorHost:
        (webglMap?['android_emulator_host'] as String?) ?? '10.0.2.2',
  );

  final bridgeMap = doc['bridge'] as YamlMap?;
  final messages = (bridgeMap?['messages'] as YamlList?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];
  final bridge = FlunityBridgeSettings(
    enabled: (bridgeMap?['enabled'] as bool?) ?? true,
    messages: messages,
  );

  return FlunityProject(
    rootDir: rootDir,
    name: name,
    version: version,
    target: target,
    paths: paths,
    webgl: webgl,
    bridge: bridge,
  );
}

String _requireString(YamlMap doc, String key) {
  final value = doc[key];
  if (value is! String || value.isEmpty) {
    throw ManifestException('Manifest is missing required string "$key".');
  }
  return value;
}

String? _optionalString(YamlMap doc, String key) {
  final value = doc[key];
  return value is String ? value : null;
}

String _resolvePath(String rootDir, YamlMap? pathsMap, String key, String fallback) {
  final raw = (pathsMap?[key] as String?) ?? fallback;
  return p.normalize(p.join(rootDir, raw));
}
```

- [ ] **Step 5: Run test, confirm pass**

Run: `dart test test/manifest/flunity_project_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/manifest packages/flunity_cli/test/manifest
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): FlunityProject manifest model + loader"
```

### Task 5: Manifest finder

**Files:**
- Create: `packages/flunity_cli/lib/src/manifest/manifest_finder.dart`
- Create: `packages/flunity_cli/test/manifest/manifest_finder_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_finder_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('finds manifest in current directory', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    expect(findManifest(start: tmp.path), p.join(tmp.path, 'flunity.yaml'));
  });

  test('walks upward', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final nested = Directory(p.join(tmp.path, 'flutter_app', 'lib'))
      ..createSync(recursive: true);
    expect(findManifest(start: nested.path), p.join(tmp.path, 'flunity.yaml'));
  });

  test('returns null when not found', () {
    expect(findManifest(start: tmp.path), isNull);
  });
}
```

- [ ] **Step 2: Run, confirm fail.** `dart test test/manifest/manifest_finder_test.dart`

- [ ] **Step 3: Implement `manifest_finder.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// Walks upward from [start] looking for a `flunity.yaml`. Returns the path
/// or `null` if none was found before reaching the filesystem root.
String? findManifest({required String start}) {
  Directory dir = Directory(p.absolute(start));
  while (true) {
    final candidate = File(p.join(dir.path, 'flunity.yaml'));
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}
```

- [ ] **Step 4: Run, confirm pass.** Expected: `+3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/manifest/manifest_finder.dart packages/flunity_cli/test/manifest/manifest_finder_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): manifest finder walks parents"
```

---

## Phase 3 — Template renderer

### Task 6: `TemplateRenderer` (TDD)

**Files:**
- Create: `packages/flunity_cli/lib/src/templates/template_renderer.dart`
- Create: `packages/flunity_cli/test/templates/template_renderer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flunity_cli/src/templates/template_renderer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Directory templateDir;
  late Directory outputDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_template_');
    templateDir = Directory(p.join(tmp.path, 'tpl'))..createSync();
    outputDir = Directory(p.join(tmp.path, 'out'))..createSync();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('substitutes __var__ in file contents', () async {
    File(p.join(templateDir.path, 'README.md'))
        .writeAsStringSync('Project: __app_name__');

    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: {'app_name': 'my_app'},
    );

    expect(
      File(p.join(outputDir.path, 'README.md')).readAsStringSync(),
      'Project: my_app',
    );
  });

  test('substitutes __var__ in file and directory names', () async {
    final nested = Directory(p.join(templateDir.path, '__app_name__'))..createSync();
    File(p.join(nested.path, '__app_name___main.dart'))
        .writeAsStringSync('// __app_name__');

    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: {'app_name': 'my_app'},
    );

    expect(
      File(p.join(outputDir.path, 'my_app', 'my_app_main.dart')).readAsStringSync(),
      '// my_app',
    );
  });

  test('preserves files without placeholders untouched', () async {
    File(p.join(templateDir.path, 'static.txt')).writeAsStringSync('hello');
    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: {'app_name': 'x'},
    );
    expect(File(p.join(outputDir.path, 'static.txt')).readAsStringSync(), 'hello');
  });

  test('throws when required variable is missing', () async {
    File(p.join(templateDir.path, 'a.txt')).writeAsStringSync('__missing__');
    expect(
      () => renderTemplate(
        from: templateDir.path,
        to: outputDir.path,
        variables: {},
      ),
      throwsA(isA<TemplateException>()),
    );
  });

  test('refuses to overwrite an existing destination unless force=true', () async {
    File(p.join(outputDir.path, 'existing.txt')).writeAsStringSync('keep me');
    File(p.join(templateDir.path, 'existing.txt')).writeAsStringSync('NEW');

    expect(
      () => renderTemplate(
        from: templateDir.path,
        to: outputDir.path,
        variables: const {},
      ),
      throwsA(isA<TemplateException>()),
    );

    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: const {},
      force: true,
    );
    expect(File(p.join(outputDir.path, 'existing.txt')).readAsStringSync(), 'NEW');
  });
}
```

- [ ] **Step 2: Run, confirm fail.**

- [ ] **Step 3: Implement `template_renderer.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

class TemplateException implements Exception {
  TemplateException(this.message);
  final String message;
  @override
  String toString() => 'TemplateException: $message';
}

/// Recursively copies [from] → [to], substituting `__key__` placeholders in
/// file contents AND in file/directory names with values from [variables].
///
/// Refuses to overwrite existing destination files unless [force] is true.
/// Throws a [TemplateException] if a placeholder has no matching variable.
Future<void> renderTemplate({
  required String from,
  required String to,
  required Map<String, String> variables,
  bool force = false,
}) async {
  final source = Directory(from);
  if (!source.existsSync()) {
    throw TemplateException('Template directory not found: $from');
  }
  await _renderDirectory(source, Directory(to), variables, force);
}

Future<void> _renderDirectory(
  Directory source,
  Directory destination,
  Map<String, String> vars,
  bool force,
) async {
  if (!destination.existsSync()) destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final substitutedName = _substitute(p.basename(entity.path), vars);
    final destPath = p.join(destination.path, substitutedName);
    if (entity is Directory) {
      await _renderDirectory(entity, Directory(destPath), vars, force);
    } else if (entity is File) {
      final destFile = File(destPath);
      if (destFile.existsSync() && !force) {
        throw TemplateException(
          'Refusing to overwrite existing file: $destPath (use force=true)',
        );
      }
      final content = _substitute(entity.readAsStringSync(), vars);
      destFile.writeAsStringSync(content);
    }
  }
}

final RegExp _placeholder = RegExp(r'__([a-zA-Z][a-zA-Z0-9_]*)__');

String _substitute(String input, Map<String, String> vars) {
  return input.replaceAllMapped(_placeholder, (m) {
    final key = m.group(1)!;
    final value = vars[key];
    if (value == null) {
      throw TemplateException('Missing template variable: $key');
    }
    return value;
  });
}
```

- [ ] **Step 4: Run, confirm pass.** Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/templates packages/flunity_cli/test/templates
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): TemplateRenderer with __var__ substitution"
```

---

## Phase 4 — `flunity create`

### Task 7: Minimal template tree + create command

**Files:**
- Create: `packages/flunity_cli/templates/flutter_webgl_basic/__app_name__/` tree (skeleton — Plan C polishes content)
- Create: `packages/flunity_cli/lib/src/templates/template_vars.dart`
- Create: `packages/flunity_cli/lib/src/commands/create_command.dart`
- Create: `packages/flunity_cli/test/commands/create_command_test.dart`

- [ ] **Step 1: Build the minimal template tree**

The template at `packages/flunity_cli/templates/flutter_webgl_basic/` is a directory tree with these files. Use `__app_name__` and other placeholders where appropriate. Plan C extends this; Plan B just needs it to be a valid scaffold.

Files (paths relative to `packages/flunity_cli/templates/flutter_webgl_basic/`):

`flunity.yaml`:
```yaml
name: __app_name__
version: 0.1.0
target: webgl

paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_build: unity_project/Builds/WebGL
  flutter_assets: flutter_app/assets/unity_webgl

webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false
  android_emulator_host: 10.0.2.2

bridge:
  enabled: true
  messages: []
```

`README.md`:
```markdown
# __app_name__

Generated by Flunity. Run `fl doctor` to verify your environment, then follow the [main repo README](https://github.com/RubenNunez/flunity#how-to) end-to-end walkthrough.
```

`.gitignore`:
```
.DS_Store
.idea/
.vscode/
*.iml
```

`flutter_app/pubspec.yaml`:
```yaml
name: __app_name__
description: __app_name__ — a Flunity-scaffolded Flutter + Unity WebGL app.
version: 0.1.0
publish_to: none

environment:
  flutter: ^3.24.0
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flunity_bridge: ^0.1.0

dev_dependencies:
  flutter_lints: ^4.0.0
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
  assets:
    - assets/unity_webgl/
```

`flutter_app/lib/main.dart`:
```dart
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

void main() {
  registerBuiltInMessages();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '__app_name__',
      home: Scaffold(
        appBar: AppBar(title: const Text('__app_name__')),
        body: const Center(child: Text('Flunity scaffold — wire up FlunityWebGLView next.')),
      ),
    );
  }
}
```

`flutter_app/assets/unity_webgl/.gitkeep`:
```
```
(empty file)

`unity_project/README.md`:
```markdown
# __app_name__ — Unity project

Open this folder in Unity 2022.3 LTS or newer. Build the WebGL target into `Builds/WebGL/`, then run `fl webgl serve` from the project root.
```

`unity_project/.gitignore`:
```
Library/
Temp/
Builds/
Logs/
obj/
MemoryCaptures/
UserSettings/
*.csproj
*.sln
*.unityproj
```

`scripts/serve_unity_webgl.sh`:
```bash
#!/usr/bin/env bash
exec flunity webgl serve "$@"
```

`scripts/copy_unity_webgl_to_flutter_assets.sh`:
```bash
#!/usr/bin/env bash
exec flunity webgl copy "$@"
```

(Make scripts executable: `chmod +x` after writing them, but `git` only tracks the executable bit if explicitly set via `git update-index --chmod=+x` or via `core.fileMode`. For simplicity, leave the files as-is; users can `chmod +x` themselves. Plan C will revisit.)

- [ ] **Step 2: Implement `template_vars.dart`**

```dart
/// Builds the standard variable map used by every Flunity template render.
Map<String, String> buildTemplateVariables({
  required String appName,
  String? org,
  String flunityBridgeVersion = '0.1.0',
}) {
  final pascal = _toPascalCase(appName);
  final inferredOrg = org ?? 'com.example';
  final bundleId = '$inferredOrg.${appName.replaceAll('_', '')}';
  return <String, String>{
    'app_name': appName,
    'app_name_pascal': pascal,
    'org': inferredOrg,
    'bundle_id': bundleId,
    'bridge_version': flunityBridgeVersion,
  };
}

String _toPascalCase(String input) {
  return input
      .split(RegExp(r'[_-]'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0].toUpperCase() + s.substring(1))
      .join();
}
```

- [ ] **Step 3: Implement `create_command.dart`**

```dart
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/templates/template_renderer.dart';
import 'package:flunity_cli/src/templates/template_vars.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class CreateCommand extends Command<int> {
  CreateCommand({required Logger logger, String? templateRootOverride})
      : _logger = logger,
        _templateRootOverride = templateRootOverride {
    argParser
      ..addOption(
        'target',
        defaultsTo: 'webgl',
        help: 'Target platform. v1 only supports "webgl".',
      )
      ..addOption(
        'org',
        defaultsTo: 'com.example',
        help: 'Reverse-DNS organization for the bundle ID.',
      )
      ..addFlag(
        'no-bridge',
        negatable: false,
        help: 'Use the basic template without bridge wiring.',
      );
  }

  final Logger _logger;
  final String? _templateRootOverride;

  @override
  String get name => 'create';

  @override
  String get description => 'Scaffold a new Flunity project.';

  @override
  String get invocation => 'flunity create <name> [options]';

  @override
  Future<int> run() async {
    final restArgs = argResults!.rest;
    if (restArgs.length != 1) {
      _logger.err('Expected exactly one positional argument: <name>');
      return 64;
    }
    final appName = restArgs.first;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(appName)) {
      _logger.err(
        'App name must be lower_snake_case starting with a letter (got "$appName").',
      );
      return 64;
    }
    final target = argResults!['target'] as String;
    if (target != 'webgl') {
      _logger.err(
        'Target "$target" is not supported in v1. See docs/native-roadmap.md.',
      );
      return 64;
    }

    final templateName =
        argResults!['no-bridge'] == true ? 'flutter_webgl_basic' : 'flutter_webgl_basic';
    // (Plan C swaps the default to flutter_webgl_bridge once that template ships.)

    final templateRoot = _resolveTemplateRoot();
    final templatePath = p.join(templateRoot, templateName);
    if (!Directory(templatePath).existsSync()) {
      _logger.err('Template not found at $templatePath');
      return 70;
    }

    final outputPath = p.absolute(appName);
    if (Directory(outputPath).existsSync()) {
      _logger.err('Directory already exists: $outputPath');
      return 73;
    }

    final variables = buildTemplateVariables(
      appName: appName,
      org: argResults!['org'] as String,
    );

    final progress = _logger.progress('Rendering $templateName → $outputPath');
    try {
      await renderTemplate(
        from: templatePath,
        to: outputPath,
        variables: variables,
      );
      progress.complete('Rendered $appName/');
    } catch (e) {
      progress.fail();
      _logger.err('Failed to render template: $e');
      return 70;
    }

    _logger
      ..info('')
      ..success('Created $appName/. Next steps:')
      ..info('  1. cd $appName')
      ..info('  2. fl doctor                            # verify environment')
      ..info('  3. open unity_project/ in Unity, build WebGL → unity_project/Builds/WebGL/')
      ..info('  4. fl webgl serve                       # start dev server')
      ..info('  5. cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev');
    return 0;
  }

  String _resolveTemplateRoot() {
    if (_templateRootOverride != null) return _templateRootOverride!;
    // Locate templates/ relative to the executing script.
    // Works for `dart run bin/flunity.dart` AND for `pub global run` (where
    // Platform.script points into pub-cache/.../bin/flunity.dart-... .snapshot).
    final scriptPath = Platform.script.toFilePath();
    final scriptDir = p.dirname(scriptPath);
    // Normal layout: <pkg>/bin/flunity.dart → templates/ at <pkg>/templates
    final candidate = p.normalize(p.join(scriptDir, '..', 'templates'));
    if (Directory(candidate).existsSync()) return candidate;
    // Fallback for pub global activate: templates live alongside lib/ at <pub-cache>/hosted/.../templates
    final altCandidate =
        p.normalize(p.join(scriptDir, '..', '..', 'templates'));
    if (Directory(altCandidate).existsSync()) return altCandidate;
    return candidate; // will surface a clear error in run() if missing
  }
}
```

- [ ] **Step 4: Wire the command into `runner.dart`**

Update `packages/flunity_cli/lib/src/runner.dart`:

```dart
import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/commands/create_command.dart';
import 'package:mason_logger/mason_logger.dart';

const String flunityVersion = '0.1.0';

Future<int> runFlunityCli(List<String> args, {Logger? logger}) async {
  final log = logger ?? Logger();
  final runner = CommandRunner<int>(
    'flunity',
    'Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.',
  )
    ..argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the flunity version.',
    )
    ..addCommand(CreateCommand(logger: log));

  try {
    if (args.contains('--version') || args.contains('-v')) {
      log.info('flunity $flunityVersion');
      return 0;
    }
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    log.err(e.toString());
    return 64;
  }
}
```

- [ ] **Step 5: Write the test**

`packages/flunity_cli/test/commands/create_command_test.dart`:

```dart
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/commands/create_command.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_create_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('renders the basic template into <name>/', () async {
    // Build a tiny fake template tree so the test doesn't depend on the real one.
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))..createSync();
    final fakeBasic = Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
      ..createSync();
    File(p.join(fakeBasic.path, 'flunity.yaml'))
        .writeAsStringSync('name: __app_name__\ntarget: webgl\n');

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.error),
        templateRootOverride: fakeTemplateRoot.path,
      ));

    // run from a tmp cwd so output lands inside tmp
    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      final code = await runner.run(['create', 'my_app']);
      expect(code, 0);

      final manifest =
          File(p.join(tmp.path, 'my_app', 'flunity.yaml')).readAsStringSync();
      expect(manifest, contains('name: my_app'));
      expect(manifest, contains('target: webgl'));
    } finally {
      Directory.current = originalCwd;
    }
  });

  test('rejects an existing directory', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))..createSync();
    Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic')).createSync();
    Directory(p.join(tmp.path, 'taken')).createSync();

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.quiet),
        templateRootOverride: fakeTemplateRoot.path,
      ));

    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      expect(await runner.run(['create', 'taken']), 73);
    } finally {
      Directory.current = originalCwd;
    }
  });

  test('rejects unsupported target', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))..createSync();
    Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic')).createSync();
    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.quiet),
        templateRootOverride: fakeTemplateRoot.path,
      ));
    expect(await runner.run(['create', '--target', 'native_android', 'x']), 64);
  });

  test('rejects invalid app name', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))..createSync();
    Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic')).createSync();
    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.quiet),
        templateRootOverride: fakeTemplateRoot.path,
      ));
    expect(await runner.run(['create', 'My-App']), 64);
  });
}
```

- [ ] **Step 6: Run tests, confirm pass.** Expected: 4 tests pass.

- [ ] **Step 7: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/templates packages/flunity_cli/lib/src packages/flunity_cli/test/commands
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): flunity create command + minimal template"
```

---

## Phase 5 — `flunity doctor`

### Task 8: Doctor framework

**Files:**
- Create: `packages/flunity_cli/lib/src/doctor/check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/doctor.dart`
- Create: `packages/flunity_cli/test/doctor/checks_test.dart`

- [ ] **Step 1: Write `check.dart`**

```dart
enum CheckSeverity { ok, warn, fail }

class CheckResult {
  CheckResult({required this.severity, required this.message, this.hint});
  final CheckSeverity severity;
  final String message;
  final String? hint;

  factory CheckResult.ok(String message) =>
      CheckResult(severity: CheckSeverity.ok, message: message);
  factory CheckResult.warn(String message, {String? hint}) =>
      CheckResult(severity: CheckSeverity.warn, message: message, hint: hint);
  factory CheckResult.fail(String message, {String? hint}) =>
      CheckResult(severity: CheckSeverity.fail, message: message, hint: hint);
}

abstract class Check {
  String get name;
  Future<CheckResult> run();
}
```

- [ ] **Step 2: Write `doctor.dart`**

```dart
import 'package:mason_logger/mason_logger.dart';

import 'check.dart';

class Doctor {
  Doctor({required this.checks});
  final List<Check> checks;

  Future<int> run({required Logger logger}) async {
    var hasFail = false;
    var hasWarn = false;
    for (final check in checks) {
      final result = await check.run();
      final glyph = switch (result.severity) {
        CheckSeverity.ok => lightGreen.wrap('✓'),
        CheckSeverity.warn => yellow.wrap('⚠'),
        CheckSeverity.fail => lightRed.wrap('✗'),
      };
      logger.info('$glyph ${check.name}: ${result.message}');
      if (result.hint != null) {
        logger.info('    ↳ ${darkGray.wrap(result.hint!)}');
      }
      if (result.severity == CheckSeverity.fail) hasFail = true;
      if (result.severity == CheckSeverity.warn) hasWarn = true;
    }
    if (hasFail) return 1;
    if (hasWarn) return 0;
    return 0;
  }
}
```

- [ ] **Step 3: Tests**

```dart
import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/doctor.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

class _StubCheck implements Check {
  _StubCheck(this.name, this._result);
  @override
  final String name;
  final CheckResult _result;
  @override
  Future<CheckResult> run() async => _result;
}

void main() {
  test('doctor returns 0 when all checks pass', () async {
    final code = await Doctor(checks: [
      _StubCheck('a', CheckResult.ok('fine')),
      _StubCheck('b', CheckResult.ok('also fine')),
    ]).run(logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('doctor returns 1 when any check fails', () async {
    final code = await Doctor(checks: [
      _StubCheck('a', CheckResult.ok('fine')),
      _StubCheck('b', CheckResult.fail('broken', hint: 'fix it')),
    ]).run(logger: Logger(level: Level.quiet));
    expect(code, 1);
  });

  test('doctor returns 0 with warnings only', () async {
    final code = await Doctor(checks: [
      _StubCheck('a', CheckResult.warn('hmm')),
    ]).run(logger: Logger(level: Level.quiet));
    expect(code, 0);
  });
}
```

- [ ] **Step 4: Run tests, confirm pass.**

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/doctor packages/flunity_cli/test/doctor
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): doctor framework + Check abstraction"
```

### Task 9: Built-in checks + `doctor` command

**Files:**
- Create: `packages/flunity_cli/lib/src/doctor/checks/manifest_present_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/unity_project_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/unity_build_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/flutter_assets_declared_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/flutter_sdk_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/dart_sdk_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/port_available_check.dart`
- Create: `packages/flunity_cli/lib/src/commands/doctor_command.dart`
- Modify: `packages/flunity_cli/lib/src/runner.dart` (add DoctorCommand)
- Test: `packages/flunity_cli/test/doctor/built_in_checks_test.dart`

- [ ] **Step 1: Implement each check**

`manifest_present_check.dart`:

```dart
import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';

class ManifestPresentCheck implements Check {
  ManifestPresentCheck({required this.cwd});
  final String cwd;

  @override
  String get name => 'flunity.yaml present';

  @override
  Future<CheckResult> run() async {
    final found = findManifest(start: cwd);
    if (found == null) {
      return CheckResult.fail(
        'No flunity.yaml found from $cwd upward.',
        hint: 'Run `fl create <name>` to scaffold a project.',
      );
    }
    return CheckResult.ok('Found at $found');
  }
}
```

`unity_project_check.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';

class UnityProjectCheck implements Check {
  UnityProjectCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'unity_project/ exists';

  @override
  Future<CheckResult> run() async {
    final exists = Directory(project.paths.unityProject).existsSync();
    return exists
        ? CheckResult.ok(project.paths.unityProject)
        : CheckResult.fail(
            'Missing: ${project.paths.unityProject}',
            hint: 'Open Unity and create a project at this path.',
          );
  }
}
```

`unity_build_check.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

class UnityBuildCheck implements Check {
  UnityBuildCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'Unity WebGL build';

  @override
  Future<CheckResult> run() async {
    final indexHtml = File(p.join(project.paths.unityBuild, 'index.html'));
    if (!indexHtml.existsSync()) {
      return CheckResult.warn(
        'No build at ${project.paths.unityBuild}/index.html',
        hint: 'Build WebGL from Unity into ${project.paths.unityBuild}/.',
      );
    }
    return CheckResult.ok('Found at ${indexHtml.path}');
  }
}
```

`flutter_assets_declared_check.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

class FlutterAssetsDeclaredCheck implements Check {
  FlutterAssetsDeclaredCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'flutter_app/pubspec.yaml declares unity_webgl assets';

  @override
  Future<CheckResult> run() async {
    final pubspec =
        File(p.join(project.paths.flutterApp, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return CheckResult.fail(
        'pubspec.yaml not found at ${pubspec.path}',
        hint: 'Run `fl create` from scratch, or add a Flutter app at this path.',
      );
    }
    final content = pubspec.readAsStringSync();
    if (!content.contains('assets/unity_webgl/')) {
      return CheckResult.warn(
        'flutter_app/pubspec.yaml does not declare assets/unity_webgl/.',
        hint:
            'Add `- assets/unity_webgl/` under `flutter: assets:` so bundled mode works.',
      );
    }
    return CheckResult.ok('Asset directory declared.');
  }
}
```

`flutter_sdk_check.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:pub_semver/pub_semver.dart';

class FlutterSdkCheck implements Check {
  FlutterSdkCheck({this.minimumVersion});
  final Version? minimumVersion;
  static final _minimum = Version(3, 24, 0);

  @override
  String get name => 'Flutter SDK';

  @override
  Future<CheckResult> run() async {
    try {
      final result = await Process.run('flutter', ['--version', '--machine']);
      if (result.exitCode != 0) {
        return CheckResult.fail('Could not run `flutter --version`.',
            hint: 'Is Flutter installed and on PATH?');
      }
      final output = result.stdout.toString();
      final match = RegExp(r'"frameworkVersion"\s*:\s*"([^"]+)"').firstMatch(output);
      if (match == null) return CheckResult.warn('Could not parse Flutter version.');
      final v = Version.parse(match.group(1)!.split('-').first);
      final minimum = minimumVersion ?? _minimum;
      if (v < minimum) {
        return CheckResult.fail('Flutter $v < required $minimum.',
            hint: 'Upgrade with `flutter upgrade`.');
      }
      return CheckResult.ok('$v');
    } catch (e) {
      return CheckResult.fail('Could not detect Flutter: $e',
          hint: 'Install Flutter from https://flutter.dev/');
    }
  }
}
```

`dart_sdk_check.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:pub_semver/pub_semver.dart';

class DartSdkCheck implements Check {
  static final _minimum = Version(3, 5, 0);

  @override
  String get name => 'Dart SDK';

  @override
  Future<CheckResult> run() async {
    final v = Version.parse(Platform.version.split(' ').first);
    if (v < _minimum) {
      return CheckResult.fail('Dart $v < required $_minimum.',
          hint: 'Upgrade Flutter (Dart ships with Flutter).');
    }
    return CheckResult.ok('$v');
  }
}
```

`port_available_check.dart`:

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';

class PortAvailableCheck implements Check {
  PortAvailableCheck({required this.host, required this.port});
  final String host;
  final int port;

  @override
  String get name => 'Dev server port $port available';

  @override
  Future<CheckResult> run() async {
    try {
      final socket = await ServerSocket.bind(host, port);
      await socket.close();
      return CheckResult.ok('$host:$port is free');
    } on SocketException {
      return CheckResult.warn(
        '$host:$port is already in use.',
        hint:
            'Either stop the other process, or set webgl.dev_server.port in flunity.yaml.',
      );
    }
  }
}
```

- [ ] **Step 2: Implement `doctor_command.dart`**

```dart
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/checks/dart_sdk_check.dart';
import 'package:flunity_cli/src/doctor/checks/flutter_assets_declared_check.dart';
import 'package:flunity_cli/src/doctor/checks/flutter_sdk_check.dart';
import 'package:flunity_cli/src/doctor/checks/manifest_present_check.dart';
import 'package:flunity_cli/src/doctor/checks/port_available_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_build_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_project_check.dart';
import 'package:flunity_cli/src/doctor/doctor.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:mason_logger/mason_logger.dart';

class DoctorCommand extends Command<int> {
  DoctorCommand({required Logger logger}) : _logger = logger;
  final Logger _logger;

  @override
  String get name => 'doctor';
  @override
  String get description => 'Check Flunity environment + project health.';

  @override
  Future<int> run() async {
    final cwd = Directory.current.path;
    final manifestPath = findManifest(start: cwd);
    final List<Check> checks = <Check>[
      DartSdkCheck(),
      FlutterSdkCheck(),
      ManifestPresentCheck(cwd: cwd),
    ];
    if (manifestPath != null) {
      final project = FlunityProject.loadFromManifest(manifestPath);
      checks.addAll(<Check>[
        UnityProjectCheck(project: project),
        UnityBuildCheck(project: project),
        FlutterAssetsDeclaredCheck(project: project),
        PortAvailableCheck(
          host: project.webgl.devServer.host,
          port: project.webgl.devServer.port,
        ),
      ]);
    }
    return Doctor(checks: checks).run(logger: _logger);
  }
}
```

- [ ] **Step 3: Wire into runner**

In `packages/flunity_cli/lib/src/runner.dart`, add:

```dart
import 'package:flunity_cli/src/commands/doctor_command.dart';
```

and inside `runFlunityCli`, add `..addCommand(DoctorCommand(logger: log))` to the runner.

- [ ] **Step 4: Tests for built-in checks**

Test the checks that don't shell out (manifest, unity_project, unity_build, flutter_assets_declared, port_available). Skip flutter/dart SDK checks in unit tests (they require shelling out).

```dart
import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/checks/flutter_assets_declared_check.dart';
import 'package:flunity_cli/src/doctor/checks/manifest_present_check.dart';
import 'package:flunity_cli/src/doctor/checks/port_available_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_build_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_project_check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_doctor_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('manifest present check finds flunity.yaml', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final r = await ManifestPresentCheck(cwd: tmp.path).run();
    expect(r.severity, CheckSeverity.ok);
  });

  test('manifest present check fails when missing', () async {
    final r = await ManifestPresentCheck(cwd: tmp.path).run();
    expect(r.severity, CheckSeverity.fail);
  });

  test('unity_project check', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    expect((await UnityProjectCheck(project: project).run()).severity, CheckSeverity.fail);
    Directory(p.join(tmp.path, 'unity_project')).createSync();
    expect((await UnityProjectCheck(project: project).run()).severity, CheckSeverity.ok);
  });

  test('unity_build check warns without index.html', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    expect((await UnityBuildCheck(project: project).run()).severity, CheckSeverity.warn);
    Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
      ..createSync(recursive: true);
    File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
        .writeAsStringSync('<html/>');
    expect((await UnityBuildCheck(project: project).run()).severity, CheckSeverity.ok);
  });

  test('flutter_assets_declared check', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    Directory(p.join(tmp.path, 'flutter_app')).createSync();
    final pubspec = File(p.join(tmp.path, 'flutter_app/pubspec.yaml'));
    pubspec.writeAsStringSync('name: a\nflutter:\n  uses-material-design: true\n');
    expect(
      (await FlutterAssetsDeclaredCheck(project: project).run()).severity,
      CheckSeverity.warn,
    );
    pubspec.writeAsStringSync(
      'name: a\nflutter:\n  assets:\n    - assets/unity_webgl/\n',
    );
    expect(
      (await FlutterAssetsDeclaredCheck(project: project).run()).severity,
      CheckSeverity.ok,
    );
  });

  test('port_available check', () async {
    final r = await PortAvailableCheck(host: '127.0.0.1', port: 0).run();
    expect(r.severity, CheckSeverity.ok); // port 0 always free
  });
}
```

- [ ] **Step 5: Run tests, confirm pass.**

- [ ] **Step 6: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/doctor/checks packages/flunity_cli/lib/src/commands/doctor_command.dart packages/flunity_cli/lib/src/runner.dart packages/flunity_cli/test/doctor/built_in_checks_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): doctor command + built-in checks"
```

---

## Phase 6 — `flunity webgl serve`

### Task 10: Unity MIME map (TDD)

**Files:**
- Create: `packages/flunity_cli/lib/src/webgl/unity_mime.dart`
- Create: `packages/flunity_cli/test/webgl/unity_mime_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run, confirm fail.**

- [ ] **Step 3: Implement `unity_mime.dart`**

```dart
import 'package:path/path.dart' as p;

const Map<String, String> _unityTypes = {
  '.wasm': 'application/wasm',
  '.data': 'application/octet-stream',
  '.framework.js': 'application/javascript',
  '.symbols.json': 'application/json',
};

/// Looks up a Unity-specific MIME type for [filename]. Strips `.br` / `.gz`
/// suffixes before matching so precompressed assets get the underlying type.
/// Returns null when nothing matches.
String? unityMimeType(String filename) {
  var name = filename.toLowerCase();
  if (name.endsWith('.br') || name.endsWith('.gz')) {
    name = name.substring(0, name.length - 3);
  }
  for (final entry in _unityTypes.entries) {
    if (name.endsWith(entry.key)) return entry.value;
  }
  final ext = p.extension(name);
  return _fallbackTypes[ext];
}

const Map<String, String> _fallbackTypes = {
  '.html': 'text/html; charset=utf-8',
  '.htm': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
};

/// Returns the encoding (`br` or `gzip`) implied by the filename's compression
/// suffix, or null if uncompressed.
String? unityContentEncoding(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.br')) return 'br';
  if (lower.endsWith('.gz')) return 'gzip';
  return null;
}
```

- [ ] **Step 4: Run, confirm pass.** Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/webgl/unity_mime.dart packages/flunity_cli/test/webgl/unity_mime_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): Unity-aware MIME mapping with brotli/gzip handling"
```

### Task 11: Dev server (TDD via real HTTP)

**Files:**
- Create: `packages/flunity_cli/lib/src/webgl/dev_server.dart`
- Create: `packages/flunity_cli/test/webgl/dev_server_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flunity_cli/src/webgl/dev_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flunity_serve_');
    File(p.join(root.path, 'index.html'))
        .writeAsStringSync('<!doctype html><title>x</title>');
    File(p.join(root.path, 'app.wasm')).writeAsBytesSync(<int>[0, 1, 2]);
    File(p.join(root.path, 'app.wasm.br'))
        .writeAsBytesSync(List<int>.filled(8, 0xff));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('serves index.html with COOP/COEP headers and HTML mime', () async {
    final server = await UnityDevServer.start(rootDir: root.path, port: 0);
    addTearDown(server.stop);
    final r = await _get('http://${server.host}:${server.port}/index.html');
    expect(r.statusCode, 200);
    expect(r.headers.value('cross-origin-opener-policy'), 'same-origin');
    expect(r.headers.value('cross-origin-embedder-policy'), 'require-corp');
    expect(r.headers.contentType?.mimeType, 'text/html');
  });

  test('serves .wasm with application/wasm', () async {
    final server = await UnityDevServer.start(rootDir: root.path, port: 0);
    addTearDown(server.stop);
    final r = await _get('http://${server.host}:${server.port}/app.wasm');
    expect(r.statusCode, 200);
    expect(r.headers.contentType.toString(), 'application/wasm');
  });

  test('precompressed .wasm.br served at /app.wasm with Content-Encoding: br',
      () async {
    final server = await UnityDevServer.start(rootDir: root.path, port: 0);
    addTearDown(server.stop);
    final r = await _get(
        'http://${server.host}:${server.port}/app.wasm',
        acceptEncoding: 'br, gzip');
    expect(r.statusCode, 200);
    expect(r.headers.value('content-encoding'), 'br');
    expect(r.headers.contentType?.mimeType, 'application/wasm');
  });
}

Future<HttpClientResponse> _get(String url, {String? acceptEncoding}) async {
  final client = HttpClient();
  client.autoUncompress = false;
  final req = await client.getUrl(Uri.parse(url));
  if (acceptEncoding != null) {
    req.headers.set(HttpHeaders.acceptEncodingHeader, acceptEncoding);
  }
  return req.close();
}
```

- [ ] **Step 2: Run, confirm fail.**

- [ ] **Step 3: Implement `dev_server.dart`**

```dart
import 'dart:async';
import 'dart:io';

import 'package:http_multi_server/http_multi_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'unity_mime.dart';

class UnityDevServer {
  UnityDevServer._(this._server, this.rootDir);
  final HttpServer _server;
  final String rootDir;

  String get host => '127.0.0.1';
  int get port => _server.port;

  static Future<UnityDevServer> start({
    required String rootDir,
    int port = 8080,
  }) async {
    final handler = const shelf.Pipeline()
        .addMiddleware(_unityHeadersMiddleware)
        .addHandler(_buildHandler(rootDir));
    final server = await HttpMultiServer.loopback(port);
    shelf_io.serveRequests(server, handler);
    return UnityDevServer._(server, rootDir);
  }

  Future<void> stop() => _server.close(force: true);
}

shelf.Handler _buildHandler(String rootDir) {
  final root = Directory(rootDir).absolute.path;
  return (shelf.Request request) async {
    final urlPath = Uri.decodeComponent(request.url.path);
    final cleanPath = urlPath.isEmpty ? 'index.html' : urlPath;
    final filePath = p.normalize(p.join(root, cleanPath));
    if (!p.isWithin(root, filePath) && filePath != root) {
      return shelf.Response.forbidden('Path escapes root');
    }

    final accept = request.headers[HttpHeaders.acceptEncodingHeader] ?? '';
    final precompressed = await _resolvePrecompressed(filePath, accept);
    final servedFile = precompressed?.file ?? File(filePath);
    if (!servedFile.existsSync()) {
      return shelf.Response.notFound('Not found: $cleanPath');
    }

    final headers = <String, String>{};
    final mime = unityMimeType(p.basename(filePath));
    if (mime != null) headers[HttpHeaders.contentTypeHeader] = mime;
    if (precompressed != null) {
      headers[HttpHeaders.contentEncodingHeader] = precompressed.encoding;
      headers[HttpHeaders.varyHeader] = 'Accept-Encoding';
    }
    headers[HttpHeaders.cacheControlHeader] = 'no-store';

    final length = await servedFile.length();
    headers[HttpHeaders.contentLengthHeader] = '$length';

    return shelf.Response.ok(servedFile.openRead(), headers: headers);
  };
}

class _Precompressed {
  _Precompressed(this.file, this.encoding);
  final File file;
  final String encoding;
}

Future<_Precompressed?> _resolvePrecompressed(
    String filePath, String acceptEncoding) async {
  if (acceptEncoding.contains('br')) {
    final candidate = File('$filePath.br');
    if (candidate.existsSync()) return _Precompressed(candidate, 'br');
  }
  if (acceptEncoding.contains('gzip')) {
    final candidate = File('$filePath.gz');
    if (candidate.existsSync()) return _Precompressed(candidate, 'gzip');
  }
  return null;
}

shelf.Handler _unityHeadersMiddleware(shelf.Handler inner) {
  return (shelf.Request request) async {
    final response = await inner(request);
    return response.change(headers: <String, String>{
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
  };
}
```

- [ ] **Step 4: Run tests, confirm pass.** Expected: 3 tests pass.

- [ ] **Step 5: Wire `flunity webgl serve`**

Create `packages/flunity_cli/lib/src/commands/webgl_command.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:flunity_cli/src/webgl/dev_server.dart';
import 'package:flunity_cli/src/webgl/webgl_copy.dart';
import 'package:mason_logger/mason_logger.dart';

class WebGLCommand extends Command<int> {
  WebGLCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_ServeSubcommand(logger: _logger));
    addSubcommand(_CopySubcommand(logger: _logger));
    addSubcommand(_CleanSubcommand(logger: _logger));
  }

  final Logger _logger;

  @override
  String get name => 'webgl';
  @override
  String get description => 'Serve, copy, or clean Unity WebGL builds.';
}

class _ServeSubcommand extends Command<int> {
  _ServeSubcommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption('host', help: 'Override manifest host.')
      ..addOption('port', help: 'Override manifest port.')
      ..addFlag('open', defaultsTo: false, help: 'Open the URL in a browser.');
  }

  final Logger _logger;

  @override
  String get name => 'serve';
  @override
  String get description => 'Start the local Unity WebGL dev server.';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;

    final host = (argResults!['host'] as String?) ?? project.webgl.devServer.host;
    final port = int.tryParse((argResults!['port'] as String?) ?? '') ??
        project.webgl.devServer.port;
    final indexHtml = File('${project.paths.unityBuild}/index.html');
    if (!indexHtml.existsSync()) {
      _logger.err('No Unity WebGL build at ${project.paths.unityBuild}/.');
      _logger.info('Build WebGL from Unity, then re-run.');
      return 1;
    }

    final server = await UnityDevServer.start(
      rootDir: project.paths.unityBuild,
      port: port,
    );
    final url = 'http://$host:${server.port}/';
    _logger.success('Serving $url (root: ${project.paths.unityBuild})');
    _logger.info('Press Ctrl+C to stop.');

    if (argResults!['open'] == true) {
      await _openUrl(url);
    }

    final completer = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) {
      _logger.info('\nStopping…');
      completer.complete();
    });
    await completer.future;
    await server.stop();
    return 0;
  }

  Future<void> _openUrl(String url) async {
    final cmd = Platform.isMacOS
        ? ['open', url]
        : Platform.isWindows
            ? ['cmd', '/c', 'start', '', url]
            : ['xdg-open', url];
    try {
      await Process.start(cmd.first, cmd.skip(1).toList(), runInShell: true);
    } catch (_) {
      // best-effort
    }
  }
}

class _CopySubcommand extends Command<int> {
  _CopySubcommand({required Logger logger}) : _logger = logger {
    argParser.addFlag('clean', defaultsTo: false,
        help: 'Remove destination first.');
  }

  final Logger _logger;

  @override
  String get name => 'copy';
  @override
  String get description =>
      'Copy the Unity WebGL build into flutter_app/assets/unity_webgl/.';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;
    try {
      final summary = await copyWebGLBuild(
        project: project,
        clean: argResults!['clean'] == true,
      );
      _logger.success(
        'Copied ${summary.fileCount} files (${summary.totalBytes} bytes) → ${summary.destination}',
      );
      _logger.info('Build hash: ${summary.buildHash}');
      return 0;
    } on WebGLCopyException catch (e) {
      _logger.err(e.message);
      return 1;
    }
  }
}

class _CleanSubcommand extends Command<int> {
  _CleanSubcommand({required Logger logger}) : _logger = logger;
  final Logger _logger;

  @override
  String get name => 'clean';
  @override
  String get description =>
      'Remove flutter_app/assets/unity_webgl/ contents (preserves .gitkeep).';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;
    final destination = Directory(project.paths.flutterAssets);
    if (!destination.existsSync()) {
      _logger.info('Already clean: ${destination.path}');
      return 0;
    }
    for (final entity in destination.listSync()) {
      if (entity is File && entity.path.endsWith('.gitkeep')) continue;
      entity.deleteSync(recursive: true);
    }
    _logger.success('Cleaned ${destination.path}');
    return 0;
  }
}

FlunityProject? _loadProjectOrDie(Logger logger) {
  final manifestPath = findManifest(start: Directory.current.path);
  if (manifestPath == null) {
    logger.err('No flunity.yaml found. Run inside a Flunity project.');
    return null;
  }
  return FlunityProject.loadFromManifest(manifestPath);
}
```

- [ ] **Step 6: Wire `WebGLCommand` into `runner.dart`**

Add `..addCommand(WebGLCommand(logger: log))`.

- [ ] **Step 7: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/webgl/dev_server.dart packages/flunity_cli/lib/src/commands/webgl_command.dart packages/flunity_cli/test/webgl/dev_server_test.dart packages/flunity_cli/lib/src/runner.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): webgl serve/copy/clean subcommands"
```

(Note: `webgl_copy.dart` is implemented in the next task; this commit references it via import, so do this commit AFTER Task 12.)

---

## Phase 7 — `flunity webgl copy`

### Task 12: WebGL copy + manifest hash (TDD)

**Files:**
- Create: `packages/flunity_cli/lib/src/webgl/webgl_copy.dart`
- Create: `packages/flunity_cli/test/webgl/webgl_copy_test.dart`

(Note: implement this BEFORE the Phase 6 commit step that imports it. Re-order: do Task 10, Task 12, Task 11.)

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/webgl/webgl_copy.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_copy_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('copies build dir to flutter_assets and writes manifest hash', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final buildDir = Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
      ..createSync(recursive: true);
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync('<html/>');
    File(p.join(buildDir.path, 'app.wasm')).writeAsBytesSync(<int>[1, 2, 3]);

    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await copyWebGLBuild(project: project);

    expect(summary.fileCount, 2);
    expect(summary.totalBytes, greaterThan(0));
    expect(File(p.join(project.paths.flutterAssets, 'index.html')).existsSync(), isTrue);
    expect(File(p.join(project.paths.flutterAssets, 'app.wasm')).existsSync(), isTrue);
    expect(File(p.join(project.paths.flutterAssets, 'flunity_webgl_manifest.json')).existsSync(), isTrue);
    expect(summary.buildHash.length, 64);
  });

  test('clean=true removes prior contents (except .gitkeep)', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final buildDir = Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
      ..createSync(recursive: true);
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync('<html/>');

    final dest = Directory(p.join(tmp.path, 'flutter_app/assets/unity_webgl'))
      ..createSync(recursive: true);
    File(p.join(dest.path, 'old.txt')).writeAsStringSync('old');
    File(p.join(dest.path, '.gitkeep')).writeAsStringSync('');

    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    await copyWebGLBuild(project: project, clean: true);

    expect(File(p.join(dest.path, 'old.txt')).existsSync(), isFalse);
    expect(File(p.join(dest.path, '.gitkeep')).existsSync(), isTrue);
    expect(File(p.join(dest.path, 'index.html')).existsSync(), isTrue);
  });

  test('throws when build dir is missing', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    expect(
      () => copyWebGLBuild(project: project),
      throwsA(isA<WebGLCopyException>()),
    );
  });
}
```

- [ ] **Step 2: Run, confirm fail.**

- [ ] **Step 3: Implement `webgl_copy.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

class WebGLCopyException implements Exception {
  WebGLCopyException(this.message);
  final String message;
  @override
  String toString() => 'WebGLCopyException: $message';
}

class WebGLCopySummary {
  WebGLCopySummary({
    required this.destination,
    required this.fileCount,
    required this.totalBytes,
    required this.buildHash,
  });
  final String destination;
  final int fileCount;
  final int totalBytes;
  final String buildHash;
}

Future<WebGLCopySummary> copyWebGLBuild({
  required FlunityProject project,
  bool clean = false,
}) async {
  final src = Directory(project.paths.unityBuild);
  if (!src.existsSync() || !File(p.join(src.path, 'index.html')).existsSync()) {
    throw WebGLCopyException(
      'No Unity WebGL build at ${src.path}/index.html — build first.',
    );
  }
  final dst = Directory(project.paths.flutterAssets);
  if (!dst.existsSync()) dst.createSync(recursive: true);

  if (clean) {
    for (final entity in dst.listSync()) {
      if (entity is File && entity.path.endsWith('.gitkeep')) continue;
      entity.deleteSync(recursive: true);
    }
  }

  var fileCount = 0;
  var totalBytes = 0;
  final hasher = AccumulatingHash();
  for (final entity in src.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: src.path);
    final destFile = File(p.join(dst.path, rel));
    destFile.parent.createSync(recursive: true);
    final bytes = entity.readAsBytesSync();
    destFile.writeAsBytesSync(bytes);
    fileCount += 1;
    totalBytes += bytes.length;
    hasher.add(rel);
    hasher.addBytes(bytes);
  }

  final buildHash = hasher.finalize();
  final manifest = <String, Object>{
    'build_hash': buildHash,
    'file_count': fileCount,
    'total_bytes': totalBytes,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  };
  File(p.join(dst.path, 'flunity_webgl_manifest.json'))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

  return WebGLCopySummary(
    destination: dst.path,
    fileCount: fileCount,
    totalBytes: totalBytes,
    buildHash: buildHash,
  );
}

class AccumulatingHash {
  AccumulatingHash() : _bytes = <int>[];
  final List<int> _bytes;
  void add(String s) => _bytes.addAll(utf8.encode('$s\n'));
  void addBytes(List<int> b) => _bytes.addAll(b);
  String finalize() => sha256.convert(_bytes).toString();
}
```

(Note: this introduces a dependency on `crypto`. Add `crypto: ^3.0.5` to `flunity_cli/pubspec.yaml` under `dependencies:` and re-bootstrap.)

- [ ] **Step 4: Run tests, confirm pass.**

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/webgl/webgl_copy.dart packages/flunity_cli/test/webgl/webgl_copy_test.dart packages/flunity_cli/pubspec.yaml
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): webgl copy + content-hash manifest"
```

---

## Phase 8 — `flunity bridge init`

### Task 13: index.html patcher (TDD)

**Files:**
- Create: `packages/flunity_cli/lib/src/bridge/index_html_patcher.dart`
- Create: `packages/flunity_cli/test/bridge/index_html_patcher_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run, confirm fail.**

- [ ] **Step 3: Implement `index_html_patcher.dart`**

```dart
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
```

- [ ] **Step 4: Run, confirm pass.**

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/bridge/index_html_patcher.dart packages/flunity_cli/test/bridge/index_html_patcher_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): idempotent Unity index.html patcher"
```

### Task 14: bridge init command (TDD)

**Files:**
- Create: `packages/flunity_cli/lib/src/utils/pubspec_editor.dart`
- Create: `packages/flunity_cli/lib/src/bridge/bridge_init.dart`
- Create: `packages/flunity_cli/lib/src/commands/bridge_command.dart`
- Modify: `packages/flunity_cli/lib/src/runner.dart`
- Create: `packages/flunity_cli/test/bridge/bridge_init_test.dart`

- [ ] **Step 1: Implement `pubspec_editor.dart`**

```dart
import 'dart:io';

/// Adds a dependency line to a Flutter app's pubspec.yaml if missing.
/// Returns true when a change was made.
bool ensurePubspecDependency({
  required String pubspecPath,
  required String name,
  required String constraint,
}) {
  final file = File(pubspecPath);
  if (!file.existsSync()) {
    throw FileSystemException('pubspec.yaml not found', pubspecPath);
  }
  final lines = file.readAsLinesSync();

  // Already present?
  for (final line in lines) {
    if (RegExp('^  $name:').hasMatch(line)) return false;
  }

  // Find the dependencies: top-level key.
  final depsIdx = lines.indexWhere((l) => l.trim() == 'dependencies:');
  if (depsIdx < 0) {
    throw StateError('Could not locate `dependencies:` section in $pubspecPath');
  }
  // Insert immediately after `dependencies:` line.
  lines.insert(depsIdx + 1, '  $name: $constraint');
  file.writeAsStringSync(lines.join('\n') + '\n');
  return true;
}
```

- [ ] **Step 2: Implement `bridge_init.dart`**

```dart
import 'dart:io';

import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/utils/pubspec_editor.dart';
import 'package:path/path.dart' as p;

class BridgeInitException implements Exception {
  BridgeInitException(this.message);
  final String message;
  @override
  String toString() => 'BridgeInitException: $message';
}

class BridgeInitSummary {
  BridgeInitSummary({
    required this.depAdded,
    required this.filesCreated,
    required this.indexHtmlPatched,
  });
  final bool depAdded;
  final List<String> filesCreated;
  final bool indexHtmlPatched;
}

/// Wires up the Flunity bridge inside an existing project. Idempotent: re-running
/// without --force is a no-op for already-existing files. With force, overwrites.
Future<BridgeInitSummary> initBridge({
  required FlunityProject project,
  required String bridgeVersion,
  bool force = false,
}) async {
  final pubspecPath = p.join(project.paths.flutterApp, 'pubspec.yaml');
  final depAdded = ensurePubspecDependency(
    pubspecPath: pubspecPath,
    name: 'flunity_bridge',
    constraint: '^$bridgeVersion',
  );

  // Create lib/unity/ scaffolding.
  final unityDir = Directory(p.join(project.paths.flutterApp, 'lib', 'unity'))
    ..createSync(recursive: true);
  final created = <String>[];
  final files = <String, String>{
    'unity_webgl_screen.dart': _screenSrc,
    'unity_webgl_bridge.dart': _bridgeSrc,
    'unity_webgl_config.dart': _configSrc,
  };
  for (final entry in files.entries) {
    final f = File(p.join(unityDir.path, entry.key));
    if (f.existsSync() && !force) continue;
    f.writeAsStringSync(entry.value);
    created.add(f.path);
  }

  // Copy FlunityBridge.cs (and demo) into Unity Assets/Scripts/.
  final scriptsDir =
      Directory(p.join(project.paths.unityProject, 'Assets', 'Scripts'))
        ..createSync(recursive: true);
  final csFiles = <String, String>{
    'FlunityBridge.cs': _bridgeCsPlaceholder,
    'FlunityBridgeDemo.cs': _bridgeDemoPlaceholder,
  };
  for (final entry in csFiles.entries) {
    final f = File(p.join(scriptsDir.path, entry.key));
    if (f.existsSync() && !force) continue;
    f.writeAsStringSync(entry.value);
    created.add(f.path);
  }

  // Patch Unity index.html if it exists.
  var patched = false;
  final indexHtml = File(p.join(project.paths.unityBuild, 'index.html'));
  if (indexHtml.existsSync()) {
    final original = indexHtml.readAsStringSync();
    final updated = patchUnityIndexHtml(original);
    if (updated != original) {
      indexHtml.writeAsStringSync(updated);
      patched = true;
    }
  }

  return BridgeInitSummary(
    depAdded: depAdded,
    filesCreated: created,
    indexHtmlPatched: patched,
  );
}

const String _screenSrc = '''
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';
import 'unity_webgl_config.dart';

class UnityWebGLScreen extends StatelessWidget {
  const UnityWebGLScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unity')),
      body: FlunityWebGLView(
        config: resolveFlunityConfig(),
        onMessage: (m) {
          // Plan C wires real handlers; for now just log.
          debugPrint('Flunity message: \${m.type}');
        },
      ),
    );
  }
}
''';

const String _bridgeSrc = '''
// Plan C polishes this file with typed message helpers.
''';

const String _configSrc = '''
import 'package:flunity_bridge/flunity_bridge.dart';

FlunityWebGLConfig resolveFlunityConfig() {
  const mode = String.fromEnvironment('FLUNITY_MODE', defaultValue: 'bundled');
  if (mode == 'dev') {
    const host = String.fromEnvironment('FLUNITY_DEV_HOST', defaultValue: '127.0.0.1');
    const port = int.fromEnvironment('FLUNITY_DEV_PORT', defaultValue: 8080);
    return FlunityWebGLConfig.dev(host: host, port: port);
  }
  return FlunityWebGLConfig.bundled();
}
''';

const String _bridgeCsPlaceholder = '''
// Plan C ships the real FlunityBridge.cs. This placeholder is here so
// `bridge init` produces a project Unity will compile.
public static class FlunityBridge {}
''';

const String _bridgeDemoPlaceholder = '''
// Plan C ships the real FlunityBridgeDemo.cs.
''';
```

- [ ] **Step 3: Implement `bridge_command.dart`**

```dart
import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/bridge/bridge_init.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

const String defaultBridgeVersion = '0.1.0';

class BridgeCommand extends Command<int> {
  BridgeCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_InitSubcommand(logger: logger));
  }
  final Logger _logger;

  @override
  String get name => 'bridge';
  @override
  String get description =>
      'Wire flunity_bridge into the Flutter app + Unity project.';
}

class _InitSubcommand extends Command<int> {
  _InitSubcommand({required Logger logger}) : _logger = logger {
    argParser.addFlag('force', defaultsTo: false, help: 'Overwrite existing files.');
  }
  final Logger _logger;

  @override
  String get name => 'init';
  @override
  String get description => 'Initialize the Flunity bridge in the current project.';

  @override
  Future<int> run() async {
    final manifestPath = findManifest(start: p.current);
    if (manifestPath == null) {
      _logger.err('No flunity.yaml found.');
      return 64;
    }
    final project = FlunityProject.loadFromManifest(manifestPath);
    final summary = await initBridge(
      project: project,
      bridgeVersion: defaultBridgeVersion,
      force: argResults!['force'] == true,
    );

    if (summary.depAdded) {
      _logger.success('Added flunity_bridge to flutter_app/pubspec.yaml');
    }
    for (final file in summary.filesCreated) {
      _logger.info('  + $file');
    }
    if (summary.indexHtmlPatched) {
      _logger.success('Patched Unity index.html with flunity_bridge.js include');
    }
    if (summary.filesCreated.isEmpty &&
        !summary.depAdded &&
        !summary.indexHtmlPatched) {
      _logger.info('Bridge already initialized. Use --force to overwrite.');
    }
    return 0;
  }
}
```

- [ ] **Step 4: Wire into runner.** Add `..addCommand(BridgeCommand(logger: log))` in `runner.dart`.

- [ ] **Step 5: Tests for `initBridge`**

```dart
import 'dart:io';

import 'package:flunity_cli/src/bridge/bridge_init.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_bridge_init_');
    File(p.join(tmp.path, 'flunity.yaml'))
        .writeAsStringSync('name: x\ntarget: webgl');
    Directory(p.join(tmp.path, 'flutter_app')).createSync();
    File(p.join(tmp.path, 'flutter_app', 'pubspec.yaml')).writeAsStringSync(
      'name: x\n\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds dep, creates files, leaves missing index.html alone', () async {
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(summary.depAdded, isTrue);
    expect(summary.filesCreated, isNotEmpty);
    expect(summary.indexHtmlPatched, isFalse);
    final pubspec = File(p.join(tmp.path, 'flutter_app/pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('flunity_bridge: ^0.1.0'));
  });

  test('idempotent without --force', () async {
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final first = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(first.filesCreated, isNotEmpty);
    final second = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(second.filesCreated, isEmpty);
    expect(second.depAdded, isFalse);
  });

  test('patches index.html if present', () async {
    Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
        .createSync(recursive: true);
    File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
        .writeAsStringSync('<html><body></body></html>');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(summary.indexHtmlPatched, isTrue);
    final patched = File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
        .readAsStringSync();
    expect(patched, contains('flunity:patch'));
  });
}
```

- [ ] **Step 6: Run tests, confirm pass.**

- [ ] **Step 7: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/bridge packages/flunity_cli/lib/src/utils packages/flunity_cli/lib/src/commands/bridge_command.dart packages/flunity_cli/lib/src/runner.dart packages/flunity_cli/test/bridge/bridge_init_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): bridge init command"
```

---

## Phase 9 — Polish: README how-to + smoke test

### Task 15: Repo + package README "How to" walkthrough

**Files:**
- Modify: `README.md` (repo root)
- Modify: `packages/flunity_cli/README.md`

- [ ] **Step 1: Replace repo-root README** with a version that includes a `## How to` section.

The full target content for `/Volumes/Transcend/Projects/flunity/README.md`:

```markdown
# Flunity

> Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.

**Status: pre-alpha.** Under active development. Public API may change without notice until `0.1.0`.

Flunity is a development companion for Flutter + Unity projects. The first supported workflow is lightweight Unity WebGL scenes loaded inside Flutter through a WebView. Native Unity Android/iOS targets are on the roadmap but not yet implemented.

## Packages

| Package | Description |
| --- | --- |
| [`flunity_cli`](packages/flunity_cli) | The `flunity` executable (and `fl` / `fu` aliases): scaffolding, dev server, asset bundling, bridge init. |
| [`flunity_bridge`](packages/flunity_bridge) | Flutter package: `FlunityWebGLView`, controller, message types, dev/bundled config. |

## How to

### 1. Install

```bash
dart pub global activate flunity_cli
```

This installs three commands. They all do the same thing — pick whichever is easiest to type:

| Command | Purpose |
| --- | --- |
| `flunity` | canonical name (use in scripts, CI, docs) |
| `fl` | short alias |
| `fu` | short alias |

Make sure `$HOME/.pub-cache/bin` is on your PATH. Verify with `fl --version`.

### 2. Scaffold a project

```bash
fl create my_app
cd my_app
```

This creates:

```
my_app/
├── flunity.yaml          # project manifest
├── flutter_app/          # Flutter side
└── unity_project/        # Unity side (open this in Unity)
```

### 3. Verify your environment

```bash
fl doctor
```

This checks Flutter SDK, Dart SDK, the manifest, your Unity project layout, and that the dev server port is free. Each row has ✓/⚠/✗ and a hint.

### 4. Build the Unity scene

Open `my_app/unity_project/` in Unity 2022.3 LTS (or newer). Build the WebGL target into `unity_project/Builds/WebGL/`.

### 5. Run the dev loop

In one terminal:

```bash
fl webgl serve
# Serving http://127.0.0.1:8080/
```

In a second terminal:

```bash
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

The Flutter app boots, loads `http://127.0.0.1:8080/index.html` in a WebView, and the Unity scene renders inside Flutter. Iterate by rebuilding Unity → reloading the Flutter app.

> **Android emulator:** `127.0.0.1` from inside the emulator points to the emulator, not your host. Flunity automatically swaps it for `10.0.2.2`. No action needed.

### 6. Build for production

```bash
fl webgl copy
cd flutter_app
flutter build apk     # or appbundle, ipa, etc.
```

`fl webgl copy` packages the Unity build into `flutter_app/assets/unity_webgl/`. Bundled mode is the Flutter default; the production app loads Unity from inside the asset bundle via a process-local HTTP loopback (Unity WebGL refuses to load via `file://`).

## Documentation

See [`docs/`](docs/) — getting started, project structure, WebGL workflow, bridge API, production build, Android emulator notes, and the native roadmap.

## License

MIT. See [LICENSE](LICENSE).
```

- [ ] **Step 2: Replace `packages/flunity_cli/README.md`**

```markdown
# flunity_cli

The `flunity` command — a development companion for Flutter + Unity WebGL projects.

## Install

```bash
dart pub global activate flunity_cli
```

This installs three executable names that all run the same binary:

| Command | Purpose |
| --- | --- |
| `flunity` | canonical |
| `fl` | short alias |
| `fu` | short alias |

Make sure `$HOME/.pub-cache/bin` is on your PATH.

## Commands

```
fl --version
fl create <name> [--target webgl] [--org com.example] [--no-bridge]
fl doctor
fl webgl serve [--host <h>] [--port <p>] [--open]
fl webgl copy [--clean]
fl webgl clean
fl bridge init [--force]
```

## How to use Flunity

The full step-by-step walkthrough lives in the [main repo README](https://github.com/RubenNunez/flunity#how-to). Quick version:

1. `fl create my_app && cd my_app`
2. `fl doctor`
3. Open `my_app/unity_project/` in Unity, build WebGL → `unity_project/Builds/WebGL/`
4. `fl webgl serve` (one terminal)
5. `cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev` (another terminal)
6. For production: `fl webgl copy` then `flutter build <ios|apk|appbundle>`

## License

MIT.
```

- [ ] **Step 3: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add README.md packages/flunity_cli/README.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add 'How to' end-to-end walkthrough to repo + flunity_cli READMEs"
```

### Task 16: End-to-end smoke test

**Files:**
- Create: `packages/flunity_cli/test/e2e/cli_smoke_test.dart`

- [ ] **Step 1: Write the smoke test**

```dart
@TestOn('vm')
import 'dart:io';

import 'package:flunity_cli/src/runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('--version prints flunityVersion', () async {
    final code = await runFlunityCli(['--version'], logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('create + doctor + webgl serve startup smoke', () async {
    final tmp = Directory.systemTemp.createTempSync('flunity_e2e_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      // create
      final createCode = await runFlunityCli(
        ['create', 'demo'],
        logger: Logger(level: Level.quiet),
      );
      expect(createCode, 0);
      expect(Directory(p.join(tmp.path, 'demo')).existsSync(), isTrue);
      expect(File(p.join(tmp.path, 'demo', 'flunity.yaml')).existsSync(), isTrue);

      // doctor (from inside the project)
      Directory.current = p.join(tmp.path, 'demo');
      final doctorCode = await runFlunityCli(
        ['doctor'],
        logger: Logger(level: Level.quiet),
      );
      // Will fail because Unity SDK + build are missing, but should exit 1, not crash.
      expect(doctorCode, anyOf(equals(0), equals(1)));
    } finally {
      Directory.current = originalCwd;
    }
  });
}
```

(Note: this test depends on the real templates directory under `packages/flunity_cli/templates/`. The `create` command's `_resolveTemplateRoot` finds it relative to `Platform.script`. When running tests via `dart test`, `Platform.script` points at the test runner — not at `bin/flunity.dart`. So this test may fail to locate templates at runtime. Workaround: skip the real-template path by passing `templateRootOverride` — BUT `runFlunityCli` doesn't take that param.

To make this work, modify `runFlunityCli` to accept an optional `templateRootOverride` and pass it to `CreateCommand`. Same for the test: pass the absolute path to `packages/flunity_cli/templates/` via `Platform.script` resolution at test time.

OR: skip this part of the smoke test in Plan B and rely on the existing `create_command_test.dart` (which uses `templateRootOverride`). Both options are fine.

For Plan B simplicity, skip the smoke test if templates aren't found:

```dart
// inside the test:
final templatesPath = p.normalize(p.join(
  p.fromUri(Platform.script), '..', '..', 'templates'));
if (!Directory(templatesPath).existsSync()) {
  markTestSkipped('templates dir not located in test context');
  return;
}
```

For now, the safer approach: the smoke test ONLY runs `--version`. Drop the create+doctor part of this test (it's already covered by the create_command_test); the smoke test exists just to prove the CLI top-level wiring works.

Final smoke test content:

```dart
@TestOn('vm')
import 'package:flunity_cli/src/runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

void main() {
  test('--version prints and exits 0', () async {
    final code = await runFlunityCli(['--version'], logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('--help exits 0', () async {
    final code = await runFlunityCli(['--help'], logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('unknown command exits 64', () async {
    final code = await runFlunityCli(['zomg'], logger: Logger(level: Level.quiet));
    expect(code, 64);
  });
}
```

(Use this smaller form.)

- [ ] **Step 2: Run.** Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/test/e2e/cli_smoke_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "test(flunity_cli): top-level smoke test"
```

---

## Phase 10 — Workspace check + push

### Task 17: Update Melos test script for `dart test`

The workspace `melos.yaml` currently has `melos exec --dir-exists=test -- "flutter test"`. `flunity_cli` is a pure-Dart package; `flutter test` works on it but `dart test` is more direct and avoids a Flutter SDK requirement when iterating on the CLI alone.

- [ ] **Step 1: Modify `melos.yaml`** to detect Flutter packages vs pure Dart:

Replace the `test:` script entry with two:

```yaml
  test:
    description: Run tests in every package (Flutter and Dart)
    run: melos exec --dir-exists=test -- "if [ -f pubspec.yaml ] && grep -q flutter: pubspec.yaml; then flutter test; else dart test; fi"
```

Or more simply, declare two scoped scripts and have CI run both. Keep it simple — one script with conditional shell:

```yaml
  test:
    description: Run tests in every package
    run: 'melos exec --dir-exists=test -- "if grep -q ''sdk: flutter'' pubspec.yaml; then flutter test; else dart test; fi"'
```

- [ ] **Step 2: Verify all tests still pass**

```
cd /Volumes/Transcend/Projects/flunity
melos run analyze
melos run format-check
melos run test
```

Fix any formatting issues with `melos run format` (separate `style:` commit if needed).

- [ ] **Step 3: Commit any workspace changes**

```bash
git -C /Volumes/Transcend/Projects/flunity add melos.yaml
git -C /Volumes/Transcend/Projects/flunity commit -m "chore: melos test script auto-detects flutter vs dart packages"
```

### Task 18: Push and open PR

- [ ] **Step 1: Push**

```bash
git -C /Volumes/Transcend/Projects/flunity push -u origin feat/plan-b-cli
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --base main --head feat/plan-b-cli --title "Plan B: flunity_cli — five v1 commands + how-to README" --body "$(cat <<'EOF'
## Summary

Implements Plan B from `docs/superpowers/plans/2026-05-04-flunity-plan-b-cli.md`:

- New `packages/flunity_cli/` package with three executable aliases: `flunity`, `fl`, `fu`.
- Five v1 commands: `create`, `doctor`, `webgl serve`, `webgl copy`, `webgl clean`, `bridge init`.
- `flunity.yaml` manifest model + parent-walking finder.
- `__var__` template renderer with overwrite protection.
- Unity-aware MIME map with Brotli/gzip precompressed handling.
- COOP/COEP-emitting shelf static server.
- WebGL copy with content-hash manifest (cache-bust friendly).
- Idempotent Unity `index.html` patcher for the JS shim.
- Doctor framework with seven built-in checks.
- "How to" walkthrough added to repo and `flunity_cli` READMEs.

## Test plan

- [ ] `melos run analyze` clean.
- [ ] `melos run format-check` clean.
- [ ] `melos run test` passes (both `flunity_bridge` and `flunity_cli`).
- [ ] `dart pub global activate --source path packages/flunity_cli` then `fl --version` prints `flunity 0.1.0`.
- [ ] `fl create demo` produces a project; `cd demo && fl doctor` runs (some checks may warn).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Report PR URL.**

---

## Definition of done for Plan B

- [ ] `flunity_cli` package present at `packages/flunity_cli/`, bootstrapped by Melos.
- [ ] All five v1 commands (+ `webgl clean`) implemented and tested.
- [ ] Three executable aliases declared in pubspec.
- [ ] `melos run analyze` + `melos run test` + `melos run format-check` all green.
- [ ] Repo + `flunity_cli` README each contain a "How to" walkthrough.
- [ ] Branch pushed, PR opened against `main`.
- [ ] CI workflow runs against the PR (no changes needed — existing workflow runs `melos run *`).

When done: brainstorm Plan C (templates, Unity-side, examples, docs).
