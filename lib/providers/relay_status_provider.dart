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
  final String url;
  final RelayConnectionState state;
  final String? errorMessage;

  const RelayStatus({
    required this.url,
    required this.state,
    this.errorMessage,
  });

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

  /// リレーの状態を更新
  void updateRelayState(String url, RelayConnectionState newState, {String? errorMessage}) {
    if (state.containsKey(url)) {
      state = {
        ...state,
        url: state[url]!.copyWith(
          state: newState,
          errorMessage: errorMessage,
        ),
      };
    }
  }

  /// すべてのリレーをリセット
  void resetAll() {
    state = {};
  }

  /// デフォルトリレーで初期化
  void initializeWithRelays(List<String> relays) {
    final Map<String, RelayStatus> newState = {};
    for (final url in relays) {
      newState[url] = RelayStatus(url: url, state: RelayConnectionState.disconnected);
    }
    state = newState;
  }

  /// 接続中に設定
  void setConnecting(String url) {
    updateRelayState(url, RelayConnectionState.connecting);
  }

  /// 接続成功
  void setConnected(String url) {
    updateRelayState(url, RelayConnectionState.connected);
  }

  /// エラー
  void setError(String url, String errorMessage) {
    updateRelayState(url, RelayConnectionState.error, errorMessage: errorMessage);
  }

  /// 切断
  void setDisconnected(String url) {
    updateRelayState(url, RelayConnectionState.disconnected);
  }
}

