import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../services/logger_service.dart';

/// Amber連携サービス
/// NostrアカウントへのアクセスをAmberアプリ経由で行う
class AmberService {
  // Amberのパッケージ名（将来の実装で使用予定）
  // static const String _amberPackage = 'com.greenart7c3.nostrsigner';
  static const MethodChannel _channel = MethodChannel(
    'jp.godzhigella.meiso/amber',
  );
  static const EventChannel _eventChannel = EventChannel(
    'jp.godzhigella.meiso/amber_events',
  );

  // Amberからの応答を受け取るためのStreamController
  final _amberResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get amberResponseStream =>
      _amberResponseController.stream;

  StreamSubscription<dynamic>? _eventSubscription;

  /// EventChannelのリスニングを開始
  void startListening() {
    if (_eventSubscription != null) {
      AppLogger.warning(' EventChannel already listening');
      return;
    }

    AppLogger.debug('👂 Starting EventChannel listening...');
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        AppLogger.debug('📨 Received event from Amber: $event');
        if (event is Map) {
          final eventMap = Map<String, dynamic>.from(event);
          _amberResponseController.add(eventMap);
        }
      },
      onError: (Object error) {
        AppLogger.error(' EventChannel error: $error');
        _amberResponseController.addError(error);
      },
      onDone: () {
        AppLogger.info(' EventChannel closed');
      },
    );
  }

  /// EventChannelのリスニングを停止
  void stopListening() {
    AppLogger.debug(' Stopping EventChannel listening...');
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  /// リソースをクリーンアップ
  void dispose() {
    stopListening();
    _amberResponseController.close();
  }

  // Intent 経由の Amber フロー（署名/暗号化/復号化）を直列化するロック。
  // Intent フローはネイティブ側の pendingResult（単一スロット）と
  // 共有 broadcast stream の「最初に届いた result」に依存しているため、
  // 並行実行するとレスポンスを取り違える。
  // AmberService は複数箇所で都度 new されるため static で共有する。
  static Future<void> _intentFlowTail = Future<void>.value();

  Future<T> _runIntentFlow<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _intentFlowTail;
    _intentFlowTail = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  /// Amberがインストールされているか確認
  Future<bool> isAmberInstalled() async {
    if (!Platform.isAndroid) {
      return false;
    }

    // TODO: Amberのインストール状態を確認する実装
    // 現在はインストールされていると仮定
    return true;
  }

  /// Amberから公開鍵を取得
  Future<String?> getPublicKey() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      AppLogger.debug(' Requesting public key from Amber...');
      final publicKey = await _channel.invokeMethod<String>(
        'getPublicKeyFromAmber',
      );

      if (publicKey != null && publicKey.isNotEmpty) {
        AppLogger.info(
          ' Received public key from Amber: ${publicKey.substring(0, 10)}...',
        );
        return publicKey;
      }

      AppLogger.warning(' No public key received from Amber');
      return null;
    } on PlatformException catch (e) {
      AppLogger.error(
        ' Failed to get public key from Amber: ${e.code} - ${e.message}',
      );
      if (e.code == 'AMBER_USER_REJECTED') {
        throw Exception('ユーザーがAmberでの認証をキャンセルしました');
      }
      rethrow;
    } catch (e) {
      AppLogger.error(' Unexpected error getting public key from Amber: $e');
      rethrow;
    }
  }

  /// Amberでメッセージに署名
  Future<String?> signEvent(String eventJson) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      AppLogger.debug('✍️ Requesting event signature from Amber...');
      final signedEvent = await _channel.invokeMethod<String>(
        'signEventWithAmber',
        {'event': eventJson},
      );

      if (signedEvent != null && signedEvent.isNotEmpty) {
        AppLogger.info(' Received signed event from Amber');
        return signedEvent;
      }

      AppLogger.warning(' No signed event received from Amber');
      return null;
    } on PlatformException catch (e) {
      AppLogger.error(
        ' Failed to sign event with Amber: ${e.code} - ${e.message}',
      );
      if (e.code == 'AMBER_USER_REJECTED') {
        throw Exception('ユーザーがAmberでの署名をキャンセルしました');
      }
      rethrow;
    } catch (e) {
      AppLogger.error(' Unexpected error signing event with Amber: $e');
      rethrow;
    }
  }

  /// Amberアプリを開く（android_intent_plusは不要になったが、互換性のため残す）
  Future<void> openAmber() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      // Android Intent Plusを使ってAmberを開く
      await _channel.invokeMethod('launchAmber');
    } catch (e) {
      AppLogger.error(' Failed to open Amber: $e');
      rethrow;
    }
  }

  /// Google PlayでAmberのページを開く
  Future<void> openAmberInStore() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      await _channel.invokeMethod('openAmberInStore');
    } catch (e) {
      AppLogger.error(' Failed to open Amber in store: $e');
      // フォールバックとして直接URLを開く
      rethrow;
    }
  }

  /// Amberでイベントに署名（統合フロー）
  /// 未署名イベントJSONを送信し、署名済みイベントJSONを受信
  Future<String> signEventWithTimeout(
    String unsignedEventJson, {
    Duration timeout = const Duration(minutes: 2),
  }) => _runIntentFlow(
    () => _signEventWithTimeoutUnlocked(unsignedEventJson, timeout: timeout),
  );

  Future<String> _signEventWithTimeoutUnlocked(
    String unsignedEventJson, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    AppLogger.debug(
      ' Signing event with Amber (timeout: ${timeout.inSeconds}s)...',
    );

    // EventChannelのリスニングを開始（まだの場合）
    startListening();

    // 署名済みイベントを待つCompleter
    final completer = Completer<String>();
    StreamSubscription<Map<String, dynamic>>? subscription;

    // タイムアウト処理
    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError(
          TimeoutException(
            'Amber signature timeout after ${timeout.inSeconds}s',
          ),
        );
      }
    });

    // Amberからの応答を待つ
    subscription = amberResponseStream.listen(
      (response) {
        AppLogger.debug('📩 Received Amber response: $response');

        // エラーチェック
        if (response['error'] != null) {
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            subscription?.cancel();
            completer.completeError(
              Exception('Amber error: ${response['error']}'),
            );
          }
          return;
        }

        // 署名済みイベントを取得
        if (response['result'] != null) {
          final signedEvent = response['result'] as String;
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            subscription?.cancel();
            completer.complete(signedEvent);
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          timeoutTimer.cancel();
          subscription?.cancel();
          completer.completeError(error);
        }
      },
    );

    try {
      // Amberに署名リクエストを送信
      final signedEvent = await signEvent(unsignedEventJson);

      // MethodChannelから直接結果が返ってきた場合
      if (signedEvent != null && signedEvent.isNotEmpty) {
        timeoutTimer.cancel();
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(signedEvent);
        }
      }

      // Completerの結果を待つ
      return await completer.future;
    } catch (e) {
      timeoutTimer.cancel();
      subscription.cancel();
      rethrow;
    }
  }

  /// AmberでNIP-44暗号化
  /// 平文と公開鍵を送信し、暗号化されたペイロードを受信
  Future<String> encryptNip44(
    String plaintext,
    String pubkey, {
    Duration timeout = const Duration(minutes: 2),
  }) => _runIntentFlow(
    () => _encryptNip44Unlocked(plaintext, pubkey, timeout: timeout),
  );

  Future<String> _encryptNip44Unlocked(
    String plaintext,
    String pubkey, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    AppLogger.debug(
      ' Encrypting with Amber NIP-44 (timeout: ${timeout.inSeconds}s)...',
    );

    // EventChannelのリスニングを開始（まだの場合）
    startListening();

    final completer = Completer<String>();
    StreamSubscription<Map<String, dynamic>>? subscription;

    // タイムアウト処理
    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError(
          TimeoutException(
            'Amber encryption timeout after ${timeout.inSeconds}s',
          ),
        );
      }
    });

    // Amberからの応答を待つ
    subscription = amberResponseStream.listen(
      (response) {
        AppLogger.debug('📩 Received Amber encryption response: $response');

        if (response['error'] != null) {
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            subscription?.cancel();
            completer.completeError(
              Exception('Amber error: ${response['error']}'),
            );
          }
          return;
        }

        if (response['result'] != null) {
          final encrypted = response['result'] as String;
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            subscription?.cancel();
            completer.complete(encrypted);
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          timeoutTimer.cancel();
          subscription?.cancel();
          completer.completeError(error);
        }
      },
    );

    try {
      final result = await _channel.invokeMethod(
        'encryptNip44WithAmber',
        {'plaintext': plaintext, 'pubkey': pubkey},
      );

      if (result != null && result is String && result.isNotEmpty) {
        timeoutTimer.cancel();
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }

      return await completer.future;
    } catch (e) {
      timeoutTimer.cancel();
      subscription.cancel();
      rethrow;
    }
  }

  /// AmberでNIP-44復号化
  /// 暗号文と公開鍵を送信し、復号化された平文を受信
  Future<String> decryptNip44(
    String ciphertext,
    String pubkey, {
    Duration timeout = const Duration(minutes: 2),
  }) => _runIntentFlow(
    () => _decryptNip44Unlocked(ciphertext, pubkey, timeout: timeout),
  );

  Future<String> _decryptNip44Unlocked(
    String ciphertext,
    String pubkey, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    AppLogger.debug(
      ' Decrypting with Amber NIP-44 (timeout: ${timeout.inSeconds}s)...',
    );

    // EventChannelのリスニングを開始（まだの場合）
    startListening();

    final completer = Completer<String>();
    StreamSubscription<Map<String, dynamic>>? subscription;

    // タイムアウト処理
    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError(
          TimeoutException(
            'Amber decryption timeout after ${timeout.inSeconds}s',
          ),
        );
      }
    });

    // Amberからの応答を待つ
    subscription = amberResponseStream.listen(
      (response) {
        AppLogger.debug('📩 Received Amber decryption response: $response');

        if (response['error'] != null) {
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            subscription?.cancel();
            completer.completeError(
              Exception('Amber error: ${response['error']}'),
            );
          }
          return;
        }

        if (response['result'] != null) {
          final decrypted = response['result'] as String;
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            subscription?.cancel();
            completer.complete(decrypted);
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          timeoutTimer.cancel();
          subscription?.cancel();
          completer.completeError(error);
        }
      },
    );

    try {
      final result = await _channel.invokeMethod(
        'decryptNip44WithAmber',
        {'ciphertext': ciphertext, 'pubkey': pubkey},
      );

      if (result != null && result is String && result.isNotEmpty) {
        timeoutTimer.cancel();
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }

      return await completer.future;
    } catch (e) {
      timeoutTimer.cancel();
      subscription.cancel();
      rethrow;
    }
  }

  // ==================== ContentProvider経由のバックグラウンド処理 ====================
  // これらのメソッドはAmberのパーミッションが「常に許可」に設定されている場合、
  // UIを一切表示せずにバックグラウンドで処理を行います。

  /// ContentProvider経由でAmberにイベント署名を依頼（バックグラウンド処理）
  ///
  /// パーミッションが未承認の場合は`PlatformException`（code: 'AMBER_REJECTED'）をスロー
  Future<String> signEventWithContentProvider({
    required String event,
    required String npub,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      AppLogger.debug(' Signing event via ContentProvider (background)...');
      final signedEvent = await _channel.invokeMethod<String>(
        'signEventWithAmberContentProvider',
        {
          'event': event,
          'npub': npub,
        },
      );

      if (signedEvent == null) {
        throw Exception('Amber returned null');
      }

      AppLogger.info(' Event signed via ContentProvider (no UI shown)');
      return signedEvent;
    } on PlatformException catch (e) {
      if (e.code == 'AMBER_REJECTED') {
        AppLogger.warning(
          ' Permission not granted - need to show UI for approval',
        );
        rethrow;
      }
      AppLogger.error(
        ' Failed to sign event via ContentProvider: ${e.code} - ${e.message}',
      );
      rethrow;
    }
  }

  /// ContentProvider経由でAmberにNIP-44暗号化を依頼（バックグラウンド処理）
  ///
  /// パーミッションが未承認の場合は`PlatformException`（code: 'AMBER_REJECTED'）をスロー
  Future<String> encryptNip44WithContentProvider({
    required String plaintext,
    required String pubkey,
    required String npub,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      AppLogger.debug(' Encrypting via ContentProvider (background)...');
      final encrypted = await _channel.invokeMethod<String>(
        'encryptNip44WithAmberContentProvider',
        {
          'plaintext': plaintext,
          'pubkey': pubkey,
          'npub': npub,
        },
      );

      if (encrypted == null) {
        throw Exception('Amber returned null');
      }

      AppLogger.info(' Content encrypted via ContentProvider (no UI shown)');
      return encrypted;
    } on PlatformException catch (e) {
      if (e.code == 'AMBER_REJECTED') {
        AppLogger.warning(
          ' Permission not granted - need to show UI for approval',
        );
        rethrow;
      }
      AppLogger.error(
        ' Failed to encrypt via ContentProvider: ${e.code} - ${e.message}',
      );
      rethrow;
    }
  }

  /// ContentProvider経由でAmberにNIP-44復号化を依頼（バックグラウンド処理）
  ///
  /// パーミッションが未承認の場合は`PlatformException`（code: 'AMBER_REJECTED'）をスロー
  Future<String> decryptNip44WithContentProvider({
    required String ciphertext,
    required String pubkey,
    required String npub,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Amber is only available on Android');
    }

    try {
      AppLogger.debug(' Decrypting via ContentProvider (background)...');
      final decrypted = await _channel.invokeMethod<String>(
        'decryptNip44WithAmberContentProvider',
        {
          'ciphertext': ciphertext,
          'pubkey': pubkey,
          'npub': npub,
        },
      );

      if (decrypted == null) {
        throw Exception('Amber returned null');
      }

      AppLogger.info(' Content decrypted via ContentProvider (no UI shown)');
      return decrypted;
    } on PlatformException catch (e) {
      if (e.code == 'AMBER_REJECTED') {
        AppLogger.warning(
          ' Permission not granted - need to show UI for approval',
        );
        rethrow;
      }
      AppLogger.error(
        ' Failed to decrypt via ContentProvider: ${e.code} - ${e.message}',
      );
      rethrow;
    }
  }
}
