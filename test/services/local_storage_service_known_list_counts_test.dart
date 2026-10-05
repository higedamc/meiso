import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/services/local_storage_service.dart';

/// Persistence of the shrink guard's baseline: the per-list todo counts last
/// confirmed on the relays.
///
/// Kind 30001 is replaceable, so a full publish from an incomplete state
/// deletes the relay copy. The baseline has to survive across sessions
/// because it is the last line of defence against a publish that happens
/// before the first fetch of the session has completed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalStorageService service;

  Future<void> mockPathProvider(String path) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getTemporaryDirectory':
              return path;
          }
          return null;
        });
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meiso_counts_test_');
    await mockPathProvider(tempDir.path);

    service = LocalStorageService();
    await service.initialize();
  });

  tearDown(() async {
    await service.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalStorageService known list todo counts', () {
    test('returns an empty map when nothing was recorded', () {
      expect(service.getKnownListTodoCounts(), isEmpty);
    });

    test('round-trips the recorded counts', () async {
      await service.setKnownListTodoCounts({
        'default': 12,
        'meiso-list-work': 5,
      });

      final counts = service.getKnownListTodoCounts();
      expect(counts['default'], 12);
      expect(counts['meiso-list-work'], 5);
      expect(counts.length, 2);
    });

    test('a later write replaces the stored map', () async {
      await service.setKnownListTodoCounts({'default': 12});
      await service.setKnownListTodoCounts({'default': 11, 'other': 3});

      final counts = service.getKnownListTodoCounts();
      expect(counts['default'], 11);
      expect(counts['other'], 3);
    });

    test('clearAllData (logout) wipes the baseline', () async {
      await service.setKnownListTodoCounts({'default': 12});
      await service.clearAllData();
      expect(service.getKnownListTodoCounts(), isEmpty);
    });
  });
}
