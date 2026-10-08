import 'package:hive_flutter/hive_flutter.dart';

import '../../../services/logger_service.dart';
import '../domain/outbox_entry.dart';

/// 送信アウトボックスのローカル永続化データソース契約
abstract class OutboxLocalDataSource {
  /// 全エントリ(`eventId` 主キー)。
  Future<Map<String, OutboxEntry>> loadAll();

  /// エントリを追加/更新する(`eventId` が既存ならその行を置き換える)。
  Future<void> put(OutboxEntry entry);

  /// エントリを削除する。
  Future<void> remove(String eventId);

  /// 変化を監視する。
  Stream<Map<String, OutboxEntry>> watchAll();

  /// Box を閉じて物理ファイルごと削除する(ログアウト用)。
  Future<void> wipe();
}

/// Hive 実装
///
/// Box 構造: `send_outbox` Box に `eventId` をキーとして
/// [OutboxEntry.toJson] をそのまま保存する。この box は UI isolate 専用
/// (Phase 3 の背景 isolate から開かないこと)。
class OutboxLocalDataSourceHive implements OutboxLocalDataSource {
  OutboxLocalDataSourceHive({Box<Map<dynamic, dynamic>>? box}) : _box = box;

  /// Hive Box 名
  static const String boxName = 'send_outbox';

  Box<Map<dynamic, dynamic>>? _box;

  Future<Box<Map<dynamic, dynamic>>> _openBox() async {
    return _box ??= await Hive.openBox<Map<dynamic, dynamic>>(boxName);
  }

  @override
  Future<Map<String, OutboxEntry>> loadAll() async {
    final box = await _openBox();
    return _readAll(box);
  }

  @override
  Future<void> put(OutboxEntry entry) async {
    final box = await _openBox();
    await box.put(entry.eventId, entry.toJson());
  }

  @override
  Future<void> remove(String eventId) async {
    final box = await _openBox();
    await box.delete(eventId);
  }

  @override
  Stream<Map<String, OutboxEntry>> watchAll() async* {
    final box = await _openBox();
    yield _readAll(box);
    await for (final _ in box.watch()) {
      yield _readAll(box);
    }
  }

  /// Box を閉じる(テスト用)
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }

  @override
  Future<void> wipe() async {
    final box = _box;
    _box = null;
    var name = boxName;
    if (box != null && box.isOpen) {
      name = box.name;
      await box.close();
    } else if (Hive.isBoxOpen(boxName)) {
      await Hive.box<Map<dynamic, dynamic>>(boxName).close();
    }
    await Hive.deleteBoxFromDisk(name);
  }

  // === Private Helpers ===

  Map<String, OutboxEntry> _readAll(Box<Map<dynamic, dynamic>> box) {
    final result = <String, OutboxEntry>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }
      try {
        result[key.toString()] = OutboxEntry.fromJson(_deepCastMap(raw));
      } on Object catch (e) {
        AppLogger.warning('[send-outbox] エントリ復元エラー: $e');
      }
    }
    return result;
  }

  /// Map を deep copy で `Map<String, dynamic>` に変換
  /// (LocalStorageService._deepCastMap と同じ方式)
  Map<String, dynamic> _deepCastMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _deepCastMap(value));
        } else if (value is List) {
          return MapEntry(
            key.toString(),
            value.map((e) {
              if (e is Map) {
                return _deepCastMap(e);
              }
              return e;
            }).toList(),
          );
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }
}
