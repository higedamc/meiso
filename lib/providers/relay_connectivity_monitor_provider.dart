import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logger_service.dart';
import 'app_lifecycle_provider.dart';
import 'nostr_provider.dart';

/// リレー接続性の定期監視。
///
/// Rust の実 WebSocket 状態（getRelayConnectionInfo）を定期的に取得して
/// relayStatusProvider へ反映する。これにより、バックグラウンドでの切断や
/// 楽観的シードによる表示乖離が放置されず、UI が常に実態へ収束する。
///
/// 動作条件: Nostr 初期化済み かつ アプリがフォアグラウンド。
/// main.dart で `ref.read(relayConnectivityMonitorProvider)` により起動する。
final relayConnectivityMonitorProvider =
    Provider<RelayConnectivityMonitor>((ref) {
  final monitor = RelayConnectivityMonitor(ref);
  ref
    ..listen<bool>(
      nostrInitializedProvider,
      (_, next) => monitor.onConditionsChanged(),
    )
    ..listen<AppLifecycleState>(
      appLifecycleProvider,
      (_, next) => monitor.onConditionsChanged(),
    )
    ..onDispose(monitor.dispose);
  // 初期状態を評価（既に初期化済みで起動された場合に備える）
  monitor.onConditionsChanged();
  return monitor;
});

class RelayConnectivityMonitor {
  RelayConnectivityMonitor(this._ref);

  /// 定期チェックの間隔。実 WebSocket 状態の読み取りのみで
  /// ネットワーク I/O は発生しないため、比較的短くても安全。
  static const _interval = Duration(seconds: 30);

  final Ref _ref;
  Timer? _timer;
  bool _refreshing = false;

  bool get _shouldRun {
    final initialized = _ref.read(nostrInitializedProvider);
    final lifecycle = _ref.read(appLifecycleProvider);
    return initialized && lifecycle == AppLifecycleState.resumed;
  }

  /// 監視条件（初期化状態・ライフサイクル）の変化を評価し、
  /// タイマーを開始/停止する。
  void onConditionsChanged() {
    if (_shouldRun) {
      if (_timer != null) return;
      AppLogger.debug('📡 Relay connectivity monitor started');
      // 開始時に即時反映してから定期実行
      unawaited(_refresh());
      _timer = Timer.periodic(_interval, (_) => unawaited(_refresh()));
    } else {
      if (_timer == null) return;
      _timer?.cancel();
      _timer = null;
      AppLogger.debug('📡 Relay connectivity monitor stopped');
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _ref.read(nostrServiceProvider).refreshRelayStatus();
    } finally {
      _refreshing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
