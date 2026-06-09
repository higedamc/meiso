import 'package:package_info_plus/package_info_plus.dart';

Future<String> buildNostrRelayUserAgent() async {
  final info = await PackageInfo.fromPlatform();
  return 'meiso/${info.version} (Web)';
}
