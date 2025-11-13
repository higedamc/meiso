import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';

/// Key Package Local DataSource
/// 
/// LocalStorageService（Hive）を使用してKey Packageのメタデータを管理する。
/// Key Package本体はMLS DBで管理されるため、ここでは公開時刻のみを保存。
class KeyPackageLocalDataSource {
  final LocalStorageService _localStorage;
  
  const KeyPackageLocalDataSource(this._localStorage);
  
  // ========================================
  // 最後の公開時刻管理
  // ========================================
  
  /// 最後の公開時刻を保存
  /// 
  /// [dateTime]: 公開日時
  Future<void> saveLastPublishTime(DateTime dateTime) async {
    try {
      await _localStorage.setLastKeyPackagePublishTime(dateTime);
      AppLogger.debug('[KeyPackageDataSource] Last publish time saved: ${dateTime.toIso8601String()}');
    } catch (e) {
      AppLogger.error('[KeyPackageDataSource] Failed to save last publish time', error: e);
      rethrow;
    }
  }
  
  /// 最後の公開時刻を読み込み
  /// 
  /// Returns: 公開日時（存在しない場合はnull）
  Future<DateTime?> loadLastPublishTime() async {
    try {
      final dateTime = _localStorage.getLastKeyPackagePublishTime();
      if (dateTime == null) {
        AppLogger.debug('[KeyPackageDataSource] No last publish time found');
        return null;
      }
      
      AppLogger.debug('[KeyPackageDataSource] Last publish time loaded: ${dateTime.toIso8601String()}');
      return dateTime;
    } catch (e) {
      AppLogger.error('[KeyPackageDataSource] Failed to load last publish time', error: e);
      return null;
    }
  }
  
  /// 最後の公開時刻を削除
  Future<void> deleteLastPublishTime() async {
    try {
      await _localStorage.clearLastKeyPackagePublishTime();
      AppLogger.debug('[KeyPackageDataSource] Last publish time deleted');
    } catch (e) {
      AppLogger.error('[KeyPackageDataSource] Failed to delete last publish time', error: e);
      rethrow;
    }
  }
}

