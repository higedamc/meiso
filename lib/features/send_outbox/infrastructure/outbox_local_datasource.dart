import 'package:hive_flutter/hive_flutter.dart';

import '../../../services/logger_service.dart';
import '../domain/outbox_entry.dart';

/// Local persistence contract for the send outbox.
abstract class OutboxLocalDataSource {
  /// All entries, keyed by `eventId`.
  Future<Map<String, OutboxEntry>> loadAll();

  /// Adds/updates an entry (replaces the row if `eventId` already exists).
  Future<void> put(OutboxEntry entry);

  /// Removes an entry.
  Future<void> remove(String eventId);

  /// Watches the queue for changes.
  Stream<Map<String, OutboxEntry>> watchAll();

  /// Closes the box and deletes its backing file (for logout).
  Future<void> wipe();
}

/// Hive implementation.
///
/// Box layout: the `send_outbox` box stores [OutboxEntry.toJson] keyed by
/// `eventId`. This box is UI-isolate only (never open it from the Phase 3
/// background isolate).
class OutboxLocalDataSourceHive implements OutboxLocalDataSource {
  OutboxLocalDataSourceHive({Box<Map<dynamic, dynamic>>? box}) : _box = box;

  /// Hive box name.
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

  /// Closes the box (test use).
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
        AppLogger.warning('[send-outbox] Failed to restore entry: $e');
      }
    }
    return result;
  }

  /// Deep-copies a raw Hive map into `Map<String, dynamic>` (same approach
  /// as `LocalStorageService._deepCastMap`).
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
