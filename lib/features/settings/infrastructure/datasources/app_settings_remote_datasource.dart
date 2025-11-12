import '../../domain/entities/app_settings.dart';

/// アプリ設定のリモートデータソース（Nostr）
///
/// NIP-78 (Kind 30078): アプリ設定
/// NIP-65 (Kind 10002): リレーリスト
abstract class AppSettingsRemoteDataSource {
  /// Nostrからアプリ設定を取得（NIP-78 Kind 30078）
  Future<AppSettings?> fetchAppSettings(String publicKey);
  
  /// Nostrにアプリ設定を保存（NIP-78 Kind 30078）
  /// 
  /// [publicKey] ユーザーの公開鍵
  /// [settings] 保存する設定
  /// [isAmberMode] Amberモードかどうか
  Future<void> saveAppSettings({
    required String publicKey,
    required AppSettings settings,
    required bool isAmberMode,
  });
  
  /// リレーリストをNostrに保存（NIP-65 Kind 10002）
  /// 
  /// [publicKey] ユーザーの公開鍵
  /// [relays] リレーURLのリスト
  /// [isAmberMode] Amberモードかどうか
  Future<void> saveRelaysToNostr({
    required String publicKey,
    required List<String> relays,
    required bool isAmberMode,
  });
}

/// 【暫定実装】既存のNostrServiceを使用するRemoteDataSource
/// 
/// Phase 8.2では互換レイヤーから旧providerを呼び出す方式を採用
class AppSettingsRemoteDataSourceNostr implements AppSettingsRemoteDataSource {
  const AppSettingsRemoteDataSourceNostr();
  
  @override
  Future<AppSettings?> fetchAppSettings(String publicKey) async {
    // 【暫定実装】旧Providerで実装済み
    // 互換レイヤーから呼び出される
    throw UnimplementedError('Use compat layer');
  }
  
  @override
  Future<void> saveAppSettings({
    required String publicKey,
    required AppSettings settings,
    required bool isAmberMode,
  }) async {
    // 【暫定実装】旧Providerで実装済み
    // 互換レイヤーから呼び出される
    throw UnimplementedError('Use compat layer');
  }
  
  @override
  Future<void> saveRelaysToNostr({
    required String publicKey,
    required List<String> relays,
    required bool isAmberMode,
  }) async {
    // 【暫定実装】旧Providerで実装済み
    // 互換レイヤーから呼び出される
    throw UnimplementedError('Use compat layer');
  }
}

