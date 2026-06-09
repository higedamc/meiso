import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Issue #130: `User-Agent: meiso/<version> (<platform>; <os_version>)`
Future<String> buildNostrRelayUserAgent() async {
  final info = await PackageInfo.fromPlatform();
  final ver = info.version;
  final os = Platform.operatingSystem;
  var osVer = Platform.operatingSystemVersion.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (osVer.length > 120) {
    osVer = '${osVer.substring(0, 117)}...';
  }
  return 'meiso/$ver ($os; $osVer)';
}
