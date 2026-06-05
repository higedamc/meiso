import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/models/custom_list.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/services/local_storage_service.dart';

/// `LocalStorageService.clearAllData()` がログアウト時に
/// 全ての永続ストレージ（todos / settings / custom_lists）を
/// 漏れなく消去することを検証する。
///
/// 1.3.0 までは `custom_lists` ボックスがクリアされておらず、
/// ログアウト後に旧ユーザーのカスタムリストが再表示・再同期される
/// バグがあったため、これを防ぐリグレッションテスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalStorageService service;

  // path_provider の MethodChannel をモックして、Hive.initFlutter() が
  // テスト用 tempDir を ApplicationDocumentsDirectory として認識するようにする。
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
    tempDir = await Directory.systemTemp.createTemp('meiso_logout_test_');
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

  group('LocalStorageService.clearAllData', () {
    test(
        'todos / settings / custom_lists のすべてのボックスが空になる '
        '(custom_lists のリーク防止リグレッション)', () async {
      // Arrange: 全ボックスにダミーデータを書き込む。
      final todo = Todo(
        id: 'todo-1',
        title: 'テストタスク',
        date: DateTime(2026, 1, 1),
        completed: false,
        order: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await service.saveTodo(todo);

      await service.setOnboardingCompleted();
      await service.setUseAmber(true);

      final customList = CustomList(
        id: 'list-1',
        name: 'テストリスト',
        order: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await service.saveCustomLists([customList]);

      // Sanity check: ボックスが空ではない。
      expect((await service.loadTodos()).length, 1);
      expect(service.hasCompletedOnboarding(), true);
      expect(service.isUsingAmber(), true);
      expect((await service.loadCustomLists()).length, 1);

      // Act: ログアウト相当のクリア処理。
      await service.clearAllData();

      // Assert: すべてのボックスが空になる。
      expect(
        (await service.loadTodos()).isEmpty,
        true,
        reason: 'todos box must be cleared on logout',
      );
      expect(
        service.hasCompletedOnboarding(),
        false,
        reason: 'settings box (onboarding flag) must be cleared on logout',
      );
      expect(
        service.isUsingAmber(),
        false,
        reason: 'settings box (amber flag) must be cleared on logout',
      );
      expect(
        (await service.loadCustomLists()).isEmpty,
        true,
        reason:
            'custom_lists box must be cleared on logout (regression fix)',
      );
    });

    test('initialize 前に呼ぶと例外を投げる', () async {
      final fresh = LocalStorageService();
      expect(
        fresh.clearAllData,
        throwsA(isA<Exception>()),
      );
    });
  });
}
