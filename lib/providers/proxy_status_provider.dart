import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import 'app_settings_provider.dart';

/// プロキシ接続状態
enum ProxyConnectionStatus {
  unknown,    // 未テスト
  testing,    // テスト中
  connected,  // 接続成功
  failed,     // 接続失敗
}

/// プロキシ接続状態を管理するProvider
final proxyStatusProvider = StateNotifierProvider<ProxyStatusNotifier, ProxyConnectionStatus>((ref) {
  return ProxyStatusNotifier(ref);
});

class ProxyStatusNotifier extends StateNotifier<ProxyConnectionStatus> {
  ProxyStatusNotifier(this._ref) : super(ProxyConnectionStatus.unknown);

  final Ref _ref;

  /// プロキシ接続をテスト
  Future<void> testProxyConnection() async {
    state = ProxyConnectionStatus.testing;

    final appSettingsAsync = _ref.read(appSettingsProvider);
    final settings = appSettingsAsync.value;

    if (settings == null || !settings.torEnabled) {
      AppLogger.info('🔍 Tor無効のためプロキシテストをスキップ');
      state = ProxyConnectionStatus.unknown;
      return;
    }

    try {
      AppLogger.info('🔍 プロキシ接続テスト開始: ${settings.proxyUrl}');
      
      // プロキシURLをパース
      final uri = Uri.parse(settings.proxyUrl);
      final host = uri.host;
      final port = uri.port;

      if (host.isEmpty || port == 0) {
        AppLogger.warning('⚠️ 無効なプロキシURL: ${settings.proxyUrl}');
        state = ProxyConnectionStatus.failed;
        return;
      }

      // Socket接続テスト（タイムアウト3秒）
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );
        
        // 接続成功
        await socket.close();
        
        AppLogger.info('✅ プロキシ接続成功: $host:$port');
        state = ProxyConnectionStatus.connected;
      } on SocketException catch (e) {
        AppLogger.warning('❌ プロキシ接続失敗: $e');
        state = ProxyConnectionStatus.failed;
      } on TimeoutException catch (e) {
        AppLogger.warning('⏱️ プロキシ接続タイムアウト: $e');
        state = ProxyConnectionStatus.failed;
      }
    } catch (e) {
      AppLogger.error('❌ プロキシテスト中にエラー: $e');
      state = ProxyConnectionStatus.failed;
    }
  }

  /// 状態をリセット
  void reset() {
    state = ProxyConnectionStatus.unknown;
  }
}

