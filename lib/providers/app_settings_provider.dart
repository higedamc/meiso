import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/local_storage_service.dart';
import '../services/amber_service.dart';
import 'nostr_provider.dart';
import '../bridge_generated.dart/api.dart' as bridge;

/// アプリ設定を管理するProvider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return AppSettingsNotifier(ref);
});

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final Ref _ref;

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localSettings = await localStorageService.loadAppSettings();
      
      if (localSettings != null) {
        state = AsyncValue.data(localSettings);
      } else {
        // デフォルト設定を使用
        final defaultSettings = AppSettings.defaultSettings();
        state = AsyncValue.data(defaultSettings);
        await localStorageService.saveAppSettings(defaultSettings);
      }
      
      // Nostr同期は非同期で実行（初期化をブロックしない）
      _backgroundSync();
      
    } catch (e) {
      print('⚠️ アプリ設定初期化エラー: $e');
      // エラー時でもデフォルト設定で初期化
      state = AsyncValue.data(AppSettings.defaultSettings());
    }
  }

  /// バックグラウンド同期（UIブロックしない）
  Future<void> _backgroundSync() async {
    await Future.delayed(const Duration(seconds: 1));
    
    if (_ref.read(nostrInitializedProvider)) {
      try {
        print('🔄 Starting background app settings sync...');
        await syncFromNostr();
        print('✅ Background settings sync completed');
      } catch (e) {
        print('⚠️ バックグラウンド設定同期失敗: $e');
      }
    }
  }

  /// 設定を更新
  Future<void> updateSettings(AppSettings settings) async {
    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
    
    state = AsyncValue.data(updatedSettings);
    
    // ローカルストレージに保存
    await localStorageService.saveAppSettings(updatedSettings);
    
    // Nostrに同期
    await _syncToNostr(updatedSettings);
  }

  /// ダークモードを切り替え
  Future<void> toggleDarkMode() async {
    state.whenData((settings) async {
      await updateSettings(settings.copyWith(darkMode: !settings.darkMode));
    });
  }

  /// 週の開始曜日を変更
  Future<void> setWeekStartDay(int day) async {
    state.whenData((settings) async {
      await updateSettings(settings.copyWith(weekStartDay: day));
    });
  }

  /// カレンダー表示形式を変更
  Future<void> setCalendarView(String view) async {
    state.whenData((settings) async {
      await updateSettings(settings.copyWith(calendarView: view));
    });
  }

  /// 通知設定を切り替え
  Future<void> toggleNotifications() async {
    state.whenData((settings) async {
      await updateSettings(settings.copyWith(
        notificationsEnabled: !settings.notificationsEnabled,
      ));
    });
  }

  /// リレーリストを更新（ローカルのみ）
  Future<void> updateRelays(List<String> relays) async {
    state.whenData((settings) async {
      final updatedSettings = settings.copyWith(
        relays: relays,
        updatedAt: DateTime.now(),
      );
      
      state = AsyncValue.data(updatedSettings);
      
      // ローカルストレージに保存
      await localStorageService.saveAppSettings(updatedSettings);
      
      // 注意: Kind 10002への保存はsaveRelaysToNostr()で明示的に行う
    });
  }

  /// リレーリストをNostr（Kind 10002）に明示的に保存
  Future<void> saveRelaysToNostr(List<String> relays) async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のためリレーリスト保存をスキップ');
      return;
    }

    if (relays.isEmpty) {
      print('⚠️ リレーリストが空のため保存をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);

    try {
      if (isAmberMode) {
        // Amberモード: 未署名イベント作成 → 署名 → 送信
        print('🔄 Amberモードでリレーリストを保存中（Kind 10002）...');
        
        var publicKey = _ref.read(publicKeyProvider);
        var npub = _ref.read(nostrPublicKeyProvider);
        
        // 公開鍵がnullの場合、復元を試みる
        if (publicKey == null || npub == null) {
          print('⚠️ 公開鍵が未設定、復元を試みます...');
          try {
            final nostrService = _ref.read(nostrServiceProvider);
            publicKey = await nostrService.getPublicKey();
            if (publicKey != null) {
              print('✅ hex公開鍵を復元: ${publicKey.substring(0, 16)}...');
              _ref.read(publicKeyProvider.notifier).state = publicKey;
              
              npub = await nostrService.hexToNpub(publicKey);
              _ref.read(nostrPublicKeyProvider.notifier).state = npub;
              print('✅ npub公開鍵も復元: ${npub.substring(0, 16)}...');
            } else {
              throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
            }
          } catch (e) {
            print('❌ 公開鍵の復元に失敗: $e');
            throw Exception('公開鍵が設定されていません: $e');
          }
        }
        
        // 未署名イベント作成
        final unsignedRelayEvent = await bridge.createUnsignedRelayListEvent(
          relays: relays,
          publicKeyHex: publicKey,
        );
        
        // Amberで署名
        final amberService = _ref.read(amberServiceProvider);
        String signedRelayEvent;
        try {
          signedRelayEvent = await amberService.signEventWithContentProvider(
            event: unsignedRelayEvent,
            npub: npub,
          );
          print('✅ リレーリスト署名完了（バックグラウンド）');
        } on PlatformException catch (e) {
          print('⚠️ ContentProvider署名失敗 (${e.code}), UI経由で再試行');
          signedRelayEvent = await amberService.signEventWithTimeout(unsignedRelayEvent);
          print('✅ リレーリスト署名完了（UI経由）');
        }
        
        // リレーに送信
        final nostrService = _ref.read(nostrServiceProvider);
        final relayEventId = await nostrService.sendSignedEvent(signedRelayEvent);
        print('✅ リレーリスト保存完了（Kind 10002）: $relayEventId');
        
      } else {
        // 通常モード: 秘密鍵で署名
        print('🔄 通常モードでリレーリストを保存中（Kind 10002）...');
        
        final relayEventId = await bridge.saveRelayList(relays: relays);
        print('✅ リレーリスト保存完了（Kind 10002）: $relayEventId');
      }
    } catch (e, stackTrace) {
      print('❌ リレーリスト保存失敗: $e');
      print('スタックトレース: $stackTrace');
      rethrow;
    }
  }

  /// Tor設定を切り替え
  Future<void> toggleTor() async {
    state.whenData((settings) async {
      await updateSettings(settings.copyWith(torEnabled: !settings.torEnabled));
    });
  }

  /// プロキシURLを変更
  Future<void> setProxyUrl(String url) async {
    state.whenData((settings) async {
      await updateSettings(settings.copyWith(proxyUrl: url));
    });
  }

  /// Nostrに設定を同期
  Future<void> _syncToNostr(AppSettings settings) async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のため設定同期をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);

    try {
      if (isAmberMode) {
        // Amberモード: 暗号化 → 署名 → 送信
        print('🔐 Amberモードで設定を同期します');
        
        // 1. 設定をJSONに変換
        final settingsJson = jsonEncode({
          'dark_mode': settings.darkMode,
          'week_start_day': settings.weekStartDay,
          'calendar_view': settings.calendarView,
          'notifications_enabled': settings.notificationsEnabled,
          'relays': settings.relays,
          'tor_enabled': settings.torEnabled,
          'proxy_url': settings.proxyUrl,
          'updated_at': settings.updatedAt.toIso8601String(),
        });
        
        // 2. 公開鍵取得
        var publicKey = _ref.read(publicKeyProvider);
        var npub = _ref.read(nostrPublicKeyProvider);
        
        // 公開鍵がnullの場合、復元を試みる
        if (publicKey == null || npub == null) {
          print('⚠️ 公開鍵が未設定、復元を試みます...');
          try {
            final nostrService = _ref.read(nostrServiceProvider);
            publicKey = await nostrService.getPublicKey();
            if (publicKey != null) {
              print('✅ hex公開鍵を復元: ${publicKey.substring(0, 16)}...');
              _ref.read(publicKeyProvider.notifier).state = publicKey;
              
              npub = await nostrService.hexToNpub(publicKey);
              _ref.read(nostrPublicKeyProvider.notifier).state = npub;
              print('✅ npub公開鍵も復元: ${npub.substring(0, 16)}...');
            } else {
              throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
            }
          } catch (e) {
            print('❌ 公開鍵の復元に失敗: $e');
            throw Exception('公開鍵が設定されていません: $e');
          }
        }
        
        // 3. Amberで暗号化
        final amberService = _ref.read(amberServiceProvider);
        print('🔐 Amberで暗号化中...');
        
        String encryptedContent;
        try {
          encryptedContent = await amberService.encryptNip44WithContentProvider(
            plaintext: settingsJson,
            pubkey: publicKey,
            npub: npub,
          );
          print('✅ 暗号化完了（バックグラウンド）');
        } on PlatformException catch (e) {
          print('⚠️ ContentProvider暗号化失敗 (${e.code}), UI経由で再試行');
          encryptedContent = await amberService.encryptNip44(settingsJson, publicKey);
          print('✅ 暗号化完了（UI経由）');
        }
        
        // 4. 未署名イベントを作成
        final unsignedEvent = await bridge.createUnsignedEncryptedAppSettingsEvent(
          encryptedContent: encryptedContent,
          publicKeyHex: publicKey,
        );
        print('📄 未署名イベント作成完了');
        
        // 5. Amberで署名
        print('✍️ Amberで署名中...');
        
        String signedEvent;
        try {
          signedEvent = await amberService.signEventWithContentProvider(
            event: unsignedEvent,
            npub: npub,
          );
          print('✅ 署名完了（バックグラウンド）');
        } on PlatformException catch (e) {
          print('⚠️ ContentProvider署名失敗 (${e.code}), UI経由で再試行');
          signedEvent = await amberService.signEventWithTimeout(unsignedEvent);
          print('✅ 署名完了（UI経由）');
        }
        
        // 6. リレーに送信
        print('📤 リレーに送信中...');
        final nostrService = _ref.read(nostrServiceProvider);
        final eventId = await nostrService.sendSignedEvent(signedEvent);
        print('✅ 設定同期完了: $eventId');
        
        // 注意: リレーリスト（Kind 10002）は自動保存しない
        // ユーザーが明示的にリレーを追加・削除した場合のみ保存される
        
      } else {
        // 通常モード: 秘密鍵で署名
        print('🔄 通常モードで設定を同期します');
        
        final bridgeSettings = bridge.AppSettings(
          darkMode: settings.darkMode,
          weekStartDay: settings.weekStartDay,
          calendarView: settings.calendarView,
          notificationsEnabled: settings.notificationsEnabled,
          relays: settings.relays,
          torEnabled: settings.torEnabled,
          proxyUrl: settings.proxyUrl,
          updatedAt: settings.updatedAt.toIso8601String(),
        );
        
        final eventId = await bridge.saveAppSettings(settings: bridgeSettings);
        print('✅ 設定同期完了: $eventId');
        
        // 注意: リレーリスト（Kind 10002）は自動保存しない
        // ユーザーが明示的にリレーを追加・削除した場合のみ保存される
      }
    } catch (e, stackTrace) {
      print('❌ 設定同期失敗: $e');
      print('スタックトレース: $stackTrace');
    }
  }

  /// Nostrから設定を同期
  Future<void> syncFromNostr() async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のため設定同期をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);

    try {
      if (isAmberMode) {
        // Amberモード: 暗号化されたイベント取得 → 復号化
        print('🔐 Amberモードで設定を同期します');
        
        var publicKey = _ref.read(publicKeyProvider);
        var npub = _ref.read(nostrPublicKeyProvider);
        
        // 公開鍵がnullの場合、復元を試みる
        if (publicKey == null || npub == null) {
          print('⚠️ 公開鍵が未設定、復元を試みます...');
          try {
            final nostrService = _ref.read(nostrServiceProvider);
            publicKey = await nostrService.getPublicKey();
            if (publicKey != null) {
              print('✅ hex公開鍵を復元: ${publicKey.substring(0, 16)}...');
              _ref.read(publicKeyProvider.notifier).state = publicKey;
              
              npub = await nostrService.hexToNpub(publicKey);
              _ref.read(nostrPublicKeyProvider.notifier).state = npub;
              print('✅ npub公開鍵も復元: ${npub.substring(0, 16)}...');
            } else {
              throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
            }
          } catch (e) {
            print('❌ 公開鍵の復元に失敗: $e');
            throw Exception('公開鍵が設定されていません: $e');
          }
        }
        
        final encryptedEvent = await bridge.fetchEncryptedAppSettingsForPubkey(
          publicKeyHex: publicKey,
        );
        
        if (encryptedEvent == null) {
          print('⚠️ 設定イベントが見つかりません');
          return;
        }
        
        print('📥 設定イベントを取得 (Event ID: ${encryptedEvent.eventId})');
        
        // Amberで復号化
        final amberService = _ref.read(amberServiceProvider);
        print('🔓 設定を復号化中...');
        
        String decryptedJson;
        try {
          decryptedJson = await amberService.decryptNip44WithContentProvider(
            ciphertext: encryptedEvent.encryptedContent,
            pubkey: publicKey,
            npub: npub,
          );
          print('✅ 復号化完了（バックグラウンド）');
        } on PlatformException catch (e) {
          print('⚠️ ContentProvider復号化失敗 (${e.code}), UI経由で再試行');
          decryptedJson = await amberService.decryptNip44(
            encryptedEvent.encryptedContent,
            publicKey,
          );
          print('✅ 復号化完了（UI経由）');
        }
        
        final settingsMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
        
        // リレーリストは別途同期（NIP-65 Kind 10002は暗号化されない）
        List<String> syncedRelays = [];
        if (settingsMap.containsKey('relays')) {
          syncedRelays = List<String>.from(settingsMap['relays'] as List);
        }
        
        // Kind 10002からリレーリストを同期（利用可能な場合）
        try {
          final kind10002Relays = await bridge.syncRelayList();
          if (kind10002Relays.isNotEmpty) {
            syncedRelays = kind10002Relays;
            print('✅ Kind 10002からリレーリスト同期: ${syncedRelays.length}件');
          }
        } catch (e) {
          print('⚠️ Kind 10002同期失敗、設定内のリレーを使用: $e');
        }
        
        final syncedSettings = AppSettings(
          darkMode: settingsMap['dark_mode'] as bool,
          weekStartDay: settingsMap['week_start_day'] as int,
          calendarView: settingsMap['calendar_view'] as String,
          notificationsEnabled: settingsMap['notifications_enabled'] as bool,
          relays: syncedRelays,
          torEnabled: settingsMap['tor_enabled'] as bool? ?? false,
          proxyUrl: settingsMap['proxy_url'] as String? ?? 'socks5://127.0.0.1:9050',
          updatedAt: DateTime.parse(settingsMap['updated_at'] as String),
        );
        
        state = AsyncValue.data(syncedSettings);
        await localStorageService.saveAppSettings(syncedSettings);
        print('✅ 設定同期完了（Amberモード）');
        
      } else {
        // 通常モード: Rust側で復号化済みの設定を取得
        print('🔄 通常モードで設定を同期します');
        
        final bridgeSettings = await bridge.syncAppSettings();
        
        if (bridgeSettings == null) {
          print('⚠️ 設定イベントが見つかりません');
          return;
        }
        
        // リレーリストを別途同期（NIP-65 Kind 10002）
        List<String> syncedRelays = [];
        try {
          syncedRelays = await bridge.syncRelayList();
          print('✅ リレーリスト同期完了: ${syncedRelays.length}件');
        } catch (e) {
          print('⚠️ リレーリスト同期失敗: $e');
          // 既存のリレーリストを維持
          syncedRelays = bridgeSettings.relays;
        }
        
        final syncedSettings = AppSettings(
          darkMode: bridgeSettings.darkMode,
          weekStartDay: bridgeSettings.weekStartDay,
          calendarView: bridgeSettings.calendarView,
          notificationsEnabled: bridgeSettings.notificationsEnabled,
          relays: syncedRelays,
          torEnabled: bridgeSettings.torEnabled,
          proxyUrl: bridgeSettings.proxyUrl,
          updatedAt: DateTime.parse(bridgeSettings.updatedAt),
        );
        
        state = AsyncValue.data(syncedSettings);
        await localStorageService.saveAppSettings(syncedSettings);
        print('✅ 設定同期完了（通常モード）');
      }
      
    } catch (e, stackTrace) {
      print('❌ 設定同期失敗: $e');
      print('スタックトレース: $stackTrace');
    }
  }
}

/// AmberServiceのProvider
final amberServiceProvider = Provider((ref) => AmberService());

