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
