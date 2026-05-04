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
