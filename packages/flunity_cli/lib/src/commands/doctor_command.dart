import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/checks/android_sdk_check.dart';
import 'package:flunity_cli/src/doctor/checks/dart_sdk_check.dart';
import 'package:flunity_cli/src/doctor/checks/flutter_assets_declared_check.dart';
import 'package:flunity_cli/src/doctor/checks/flutter_sdk_check.dart';
import 'package:flunity_cli/src/doctor/checks/manifest_present_check.dart';
import 'package:flunity_cli/src/doctor/checks/port_available_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_binary_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_build_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_project_check.dart';
import 'package:flunity_cli/src/doctor/checks/xcode_check.dart';
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
      checks
        ..add(UnityProjectCheck(project: project))
        ..add(UnityBuildCheck(project: project))
        ..addAll(_targetSpecificChecks(project));
    }
    return Doctor(checks: checks).run(logger: _logger);
  }

  /// Per-target checks branch off the manifest's `target:` so we don't yell
  /// at the user about Xcode when they're shipping WebGL, or about
  /// COOP/COEP ports when they're shipping native.
  List<Check> _targetSpecificChecks(FlunityProject project) {
    return switch (project.target) {
      FlunityTarget.webgl => [
        FlutterAssetsDeclaredCheck(project: project),
        PortAvailableCheck(
          host: project.webgl.devServer.host,
          port: project.webgl.devServer.port,
        ),
      ],
      FlunityTarget.ios => [UnityBinaryCheck(), XcodeCheck()],
      FlunityTarget.android => [UnityBinaryCheck(), AndroidSdkCheck()],
    };
  }
}
