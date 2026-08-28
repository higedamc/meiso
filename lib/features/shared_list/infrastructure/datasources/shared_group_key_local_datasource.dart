import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/shared_group_credentials.dart';

/// 共有グループ鍵 nsec_G / npub_G のローカル永続化
class SharedGroupKeyLocalDataSource {
  const SharedGroupKeyLocalDataSource(this._storage);
  final LocalStorageService _storage;

  Future<SharedGroupCredentials?> load(String groupId) async {
    final map = _storage.loadSharedGroupCredentials();
    final raw = map[groupId];
    if (raw is! Map) {
      return null;
    }
    return SharedGroupCredentials.fromJson(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Future<void> save(SharedGroupCredentials credentials) async {
    final map = _storage.loadSharedGroupCredentials();
    map[credentials.groupId] = credentials.toJson();
    await _storage.saveSharedGroupCredentials(map);
    AppLogger.debug(
      '[SharedGroupKey] Saved credentials for ${credentials.groupId}',
    );
  }

  Future<void> delete(String groupId) async {
    final map = _storage.loadSharedGroupCredentials();
    map.remove(groupId);
    await _storage.saveSharedGroupCredentials(map);
  }
}
