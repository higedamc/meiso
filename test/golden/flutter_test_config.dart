import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Test bootstrap for `test/golden/` only.
///
/// `flutter_test_config.dart` applies to every test at or below its own
/// directory, so this file deliberately lives inside `test/golden/` and leaves
/// the rest of the suite untouched.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Goldens are compared pixel-for-pixel, so the platform that produced them
  // matters. Print it on every run so a mismatch can be traced to the renderer
  // rather than to the widget under test.
  debugPrint(
    '[golden] rendering on ${Platform.operatingSystem} '
    '(${Platform.operatingSystemVersion}), dart ${Platform.version}',
  );

  // AppTheme asks for NotoSansJP through GoogleFonts.notoSansJp(), which
  // downloads the .ttf at runtime. flutter_test answers every HTTP request with
  // status 400 and this repo does not bundle the font as an asset, so that
  // download can never succeed here. Disable fetching so the failure is
  // immediate and offline, then drop exactly that one exception: the engine
  // falls back to the FlutterTest font, which is identical on every platform,
  // so rendering is unaffected. Every other exception still fails the test.
  GoogleFonts.config.allowRuntimeFetching = false;
  final forward = reportTestException;
  reportTestException = (FlutterErrorDetails details, String testDescription) {
    if (_isGoogleFontsAssetMiss(details)) {
      debugPrint(
        '[golden] ignoring google_fonts asset miss for "$testDescription" '
        '(text renders with the FlutterTest fallback font)',
      );
      return;
    }
    forward(details, testDescription);
  };

  await testMain();
}

bool _isGoogleFontsAssetMiss(FlutterErrorDetails details) {
  return details.exception.toString().contains(
    'GoogleFonts.config.allowRuntimeFetching is false',
  );
}
