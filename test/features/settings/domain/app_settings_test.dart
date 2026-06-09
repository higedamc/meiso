import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/models/app_settings.dart';

void main() {
  group('AppSettings Entity', () {
    test('デフォルト設定が正しく生成される', () {
      final settings = AppSettings.defaultSettings();
      
      expect(settings.darkMode, false);
      expect(settings.weekStartDay, 1);
      expect(settings.calendarView, 'week');
      expect(settings.notificationsEnabled, true);
      expect(settings.relays, isEmpty);
      expect(settings.torMode, TorMode.disabled);
      expect(settings.proxyUrl, 'socks5://127.0.0.1:9050');
      expect(settings.customListOrder, isEmpty);
      expect(settings.lastViewedCustomListId, isNull);
      expect(settings.taskUiMode, TaskUiMode.reminders);
      expect(settings.featureFlags, isEmpty);
      expect(settings.hideCompletedTasks, false);
    });
    
    test('copyWithでフィールドを更新できる', () {
      final settings = AppSettings.defaultSettings();
      final updated = settings.copyWith(
        darkMode: true,
        weekStartDay: 0,
      );
      
      expect(updated.darkMode, true);
      expect(updated.weekStartDay, 0);
      expect(updated.calendarView, settings.calendarView);
      expect(updated.notificationsEnabled, settings.notificationsEnabled);
    });
    
    test('freezedによる等価性チェックが動作する', () {
      final settings1 = AppSettings(
        darkMode: true,
        weekStartDay: 1,
        calendarView: 'week',
        notificationsEnabled: true,
        relays: ['wss://relay.damus.io'],
        torMode: TorMode.disabled,
        proxyUrl: 'socks5://127.0.0.1:9050',
        customListOrder: [],
        updatedAt: DateTime(2025, 1),
      );
      
      final settings2 = settings1.copyWith();
      
      expect(settings1, equals(settings2));
    });
  });
}
