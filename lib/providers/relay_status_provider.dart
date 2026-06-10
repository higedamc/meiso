import 'package:flutter_riverpod/flutter_riverpod.dart';

/// リレーの接続状態
enum RelayConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// 個別リレーの状態
class RelayStatus {

  const RelayStatus({
    required this.url,
    required this.state,
    this.errorMessage,
  });
  final String url;
  final RelayConnectionState state;
  final String? errorMessage;

  RelayStatus copyWith({
    String? url,
    RelayConnectionState? state,
    String? errorMessage,
  }) {
    return RelayStatus(
      url: url ?? this.url,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// リレー状態を管理するProvider
final relayStatusProvider = StateNotifierProvider<RelayStatusNotifier, Map<String, RelayStatus>>((ref) {
  return RelayStatusNotifier();
});

class RelayStatusNotifier extends StateNotifier<Map<String, RelayStatus>> {
  RelayStatusNotifier() : super({});

  /// リレーを追加
  void addRelay(String url) {
    state = {
      ...state,
      url: RelayStatus(url: url, state: RelayConnectionState.disconnected),
    };
  }

  /// リレーを削除
  void removeRelay(String url) {
    final newState = Map<String, RelayStatus>.from(state);
    newState.remove(url);
    state = newState;
  }

  /// リレーリストを指定状態で初期化（デフォルトは disconnected）
  void initializeWithRelays(
    List<String> relays, {
    RelayConnectionState initialState = RelayConnectionState.disconnected,
  }) {
    final newState = <String, RelayStatus>{};
    for (final url in relays) {
      newState[url] = RelayStatus(url: url, state: initialState);
    }
    state = newState;
  }

  /// リレーリストを connected で初期化（Rust 接続成功直後の楽観的シード）
  ///
  /// 実状態は直後の refreshRelayStatus / 定期監視で補正される前提で使う。
  void initializeAsConnected(List<String> relays) {
    initializeWithRelays(relays, initialState: RelayConnectionState.connected);
  }

  /// Rust の実接続情報で状態全体を置き換える（唯一の真実）
  ///
  /// 登録済みでないリレーは upsert し、Rust 側に存在しないリレーは
  /// 除去する。表示と実態の乖離を防ぐため、接続性の更新は原則として
  /// このメソッド経由で行う。
  void applyConnectionInfo(Map<String, bool> connectionByUrl) {
    state = {
      for (final entry in connectionByUrl.entries)
        entry.key: RelayStatus(
          url: entry.key,
          state: entry.value
              ? RelayConnectionState.connected
              : RelayConnectionState.disconnected,
        ),
    };
  }

  /// 登録済みリレーを一括で disconnected にマーク
  ///
  /// 再接続失敗など、実状態の取得自体が期待できない場合の悲観的フォールバック。
  void markAllDisconnected() {
    state = {
      for (final entry in state.entries)
        entry.key: entry.value.copyWith(state: RelayConnectionState.disconnected),
    };
  }
}

