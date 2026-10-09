import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import '../../app_theme.dart';
import '../../bridge_generated.dart/api.dart' as rust_api;
import '../../features/media/application/providers/media_providers.dart';
import '../../features/send_outbox/presentation/providers/outbox_providers.dart'
    as send_outbox_providers;
import '../../features/task_comments/infrastructure/providers/repository_providers.dart'
    as task_comment_providers;
import '../../features/task_comments/infrastructure/providers/read_state_providers.dart'
    as task_comment_read_state_providers;
import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart' hide amberServiceProvider;
import '../../providers/bootstrap_sync_provider.dart';
import '../../providers/custom_lists_provider.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/sync_status_provider.dart';
import '../../providers/todos_provider.dart';

import '../../services/local_storage_service.dart';
import '../../services/logger_service.dart';
import '../../utils/relay_list_sync_guard.dart';
import 'widgets/settings_info_card.dart';

/// Auto-detected format of the text in the secret key input field.
///
/// The display label and the "is this a usable key" color cue must both be
/// derived from this enum rather than from the localized label text itself —
/// otherwise translating the label breaks the color logic in non-English
/// locales.
enum _KeyFormat { nsecValid, nsecIncomplete, hexValid, hexPartial, unknown }

String _keyFormatLabel(
  AppLocalizations l10n,
  _KeyFormat format, {
  int hexLength = 0,
}) {
  switch (format) {
    case _KeyFormat.nsecValid:
      return l10n.secretKeyFormatNsecValid;
    case _KeyFormat.nsecIncomplete:
      return l10n.secretKeyFormatNsecIncomplete;
    case _KeyFormat.hexValid:
      return l10n.secretKeyFormatHexComplete;
    case _KeyFormat.hexPartial:
      return l10n.secretKeyFormatHexProgress(hexLength);
    case _KeyFormat.unknown:
      return l10n.formatUnknown;
  }
}

class SecretKeyManagementScreen extends ConsumerStatefulWidget {
  const SecretKeyManagementScreen({super.key});

  @override
  ConsumerState<SecretKeyManagementScreen> createState() =>
      _SecretKeyManagementScreenState();
}

class _SecretKeyManagementScreenState
    extends ConsumerState<SecretKeyManagementScreen> {
  final _secretKeyController = TextEditingController();
  bool _isLoading = false;
  bool _obscureSecretKey = true;
  String? _errorMessage;
  String? _successMessage;
  _KeyFormat? _detectedKeyFormatKind; // 検出されたフォーマット (nsec/hex)
  int _detectedHexLength = 0; // _detectedKeyFormatKind == hexPartial の場合のみ有効
  bool _hasEncryptedKey = false; // 暗号化された秘密鍵が存在するか
  late final String _encryptedPlaceholder;

  @override
  void initState() {
    super.initState();
    // Initialize placeholder after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _encryptedPlaceholder = AppLocalizations.of(context).encrypted;
        });
      }
    });
    // テキスト変更時にフォーマットを自動検出
    _secretKeyController.addListener(_detectKeyFormat);
    // 暗号化された秘密鍵の存在チェック
    _checkEncryptedKey();
  }

  /// 暗号化された秘密鍵が存在するかチェック
  Future<void> _checkEncryptedKey() async {
    final nostrService = ref.read(nostrServiceProvider);
    final hasKey = await nostrService.hasEncryptedKey();

    if (hasKey && mounted) {
      setState(() {
        _hasEncryptedKey = true;
        // ログイン後、秘密鍵フィールドに暗号化状態を表示
        if (_secretKeyController.text.isEmpty) {
          _secretKeyController.text = _encryptedPlaceholder;
          _obscureSecretKey = true; // 常に非表示状態で開始
        }
      });
    }
  }

  @override
  void dispose() {
    // セキュリティ: メモリから秘密鍵をクリア
    _secretKeyController.text = '';
    _secretKeyController.dispose();
    super.dispose();
  }

  /// パスワード入力ダイアログを表示
  Future<String?> _showPasswordDialog(String title, String message) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: dialogL10n.password,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return dialogL10n.passwordRequired;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogL10n.cancelButton),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(passwordController.text);
                }
              },
              child: Text(dialogL10n.ok),
            ),
          ],
        );
      },
    );
  }

  /// nsec表示ダイアログを表示
  Future<void> _showNsecDialog(String nsec) async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.key, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              Text(l10n.secretKeyNsecLabel),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 警告メッセージ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.secretKeyNsecWarningTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.secretKeyNsecWarningBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.secretKeyColonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // nsec表示エリア
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.sectionCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SelectableText(
                    nsec,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                _copyToClipboard(nsec, l10n.secretKeyLabel);
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.copyButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.closeButton),
            ),
          ],
        );
      },
    );
  }

  /// 目のアイコンタップ時の処理
  Future<void> _handleVisibilityToggle() async {
    // 暗号化された秘密鍵が存在し、フィールドが暗号化プレースホルダーの場合
    if (_hasEncryptedKey &&
        _secretKeyController.text == _encryptedPlaceholder) {
      // パスワード入力ダイアログを表示
      final l10n = AppLocalizations.of(context);
      final password = await _showPasswordDialog(
        l10n.enterPassword,
        l10n.enterPasswordToDecrypt,
      );

      if (password == null || password.isEmpty) return;

      // パスワードで復号化を試みる
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final nostrService = ref.read(nostrServiceProvider);
        final decryptedKey = await nostrService.getSecretKey(password);

        if (decryptedKey == null) {
          setState(() {
            _errorMessage = l10n.passwordIncorrectOrDecryptFailed;
          });
          return;
        }

        // nsec表示ダイアログを表示（hex形式でもそのまま表示）
        if (mounted) {
          await _showNsecDialog(decryptedKey);
        }
      } catch (e) {
        // 復号失敗の詳細はログのみに残し、UI には鍵情報を含みうる生の例外文字列を
        // 出さない（例外メッセージへの機密混入に対する多層防御）。
        AppLogger.error('Secret key decrypt failed', error: e);
        setState(() {
          _errorMessage = l10n.secretKeyDecryptFailed(e.runtimeType.toString());
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // 通常の表示/非表示トグル
      setState(() {
        _obscureSecretKey = !_obscureSecretKey;
      });
    }
  }

  /// 秘密鍵のフォーマットを自動検出
  void _detectKeyFormat() {
    final key = _secretKeyController.text.trim();

    // 暗号化プレースホルダーの場合はスキップ
    if (key == _encryptedPlaceholder) {
      if (_detectedKeyFormatKind != null) {
        setState(() {
          _detectedKeyFormatKind = null;
        });
      }
      return;
    }

    if (key.isEmpty) {
      if (_detectedKeyFormatKind != null) {
        setState(() {
          _detectedKeyFormatKind = null;
        });
      }
      return;
    }

    _KeyFormat newFormat;
    var newHexLength = 0;

    if (key.startsWith('nsec1')) {
      // Bech32形式 (nsec)
      newFormat = key.length >= 63
          ? _KeyFormat.nsecValid
          : _KeyFormat.nsecIncomplete;
    } else if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(key)) {
      // Hex形式
      if (key.length == 64) {
        newFormat = _KeyFormat.hexValid;
      } else {
        newFormat = _KeyFormat.hexPartial;
        newHexLength = key.length;
      }
    } else {
      newFormat = _KeyFormat.unknown;
    }

    if (_detectedKeyFormatKind != newFormat ||
        _detectedHexLength != newHexLength) {
      setState(() {
        _detectedKeyFormatKind = newFormat;
        _detectedHexLength = newHexLength;
      });
    }
  }

  /// 秘密鍵のバリデーション
  String? _validateSecretKey(String key) {
    final l10n = AppLocalizations.of(context);
    if (key.isEmpty) {
      return l10n.secretKeyValidatorEmpty;
    }

    if (key.startsWith('nsec1')) {
      if (key.length < 63) {
        return l10n.secretKeyValidatorNsecLength;
      }
      return null;
    } else if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(key)) {
      if (key.length != 64) {
        return l10n.secretKeyValidatorHexLength(key.length);
      }
      return null;
    } else {
      return l10n.secretKeyValidatorFormat;
    }
  }

  Future<void> _generateNewSecretKey() async {
    final l10n = AppLocalizations.of(context);

    // パスワード入力
    final password = await _showPasswordDialog(
      l10n.setPassword,
      l10n.secretKeySetPasswordMessage,
    );

    if (password == null || password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final newKey = await nostrService.generateNewSecretKey();

      // Rust APIで暗号化して保存
      await nostrService.saveSecretKey(newKey, password);

      // 暗号化プレースホルダーを表示
      setState(() {
        _hasEncryptedKey = true;
        _secretKeyController.text = _encryptedPlaceholder;
        _obscureSecretKey = true;
        _successMessage = l10n.secretKeyGenerateSuccess;
      });

      // 自動的にリレーに接続（newKeyを使用）
      await _autoConnectWithKey(newKey);
    } catch (e) {
      AppLogger.error('Secret key generation failed', error: e);
      setState(() {
        _errorMessage = l10n.secretKeyGenerationFailed(
          e.runtimeType.toString(),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSecretKey() async {
    final secretKey = _secretKeyController.text.trim();

    // 暗号化プレースホルダーの場合: パスワードで復号して再接続
    if (secretKey == _encryptedPlaceholder) {
      final l10n = AppLocalizations.of(context);
      final password = await _showPasswordDialog(
        l10n.enterPassword,
        l10n.enterPasswordToDecrypt,
      );
      if (password == null || password.isEmpty) {
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      try {
        final nostrService = ref.read(nostrServiceProvider);
        final decryptedKey = await nostrService.getSecretKey(password);
        if (decryptedKey == null) {
          setState(() {
            _errorMessage = l10n.passwordIncorrectOrDecryptFailed;
          });
          return;
        }

        await _autoConnectWithKey(decryptedKey);
        if (mounted) {
          setState(() {
            _successMessage = l10n.connectedToRelay;
          });
        }
      } catch (e) {
        AppLogger.error('Secret key reconnect failed', error: e);
        setState(() {
          _errorMessage = l10n.secretKeySaveFailed(e.runtimeType.toString());
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    // バリデーション
    final validationError = _validateSecretKey(secretKey);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    // パスワード入力
    final l10n = AppLocalizations.of(context);
    final password = await _showPasswordDialog(
      l10n.setPassword,
      l10n.enterPasswordToEncrypt,
    );

    if (password == null || password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);

      // Rust APIで暗号化して保存
      await nostrService.saveSecretKey(secretKey, password);

      // 暗号化プレースホルダーを表示
      setState(() {
        _hasEncryptedKey = true;
        _secretKeyController.text = _encryptedPlaceholder;
        _obscureSecretKey = true;
        _successMessage = l10n.secretKeyEncrypted(
          _detectedKeyFormatKind != null
              ? _keyFormatLabel(
                  l10n,
                  _detectedKeyFormatKind!,
                  hexLength: _detectedHexLength,
                )
              : l10n.formatUnknown,
        );
      });

      // 自動的にリレーに接続（secretKeyを使用）
      await _autoConnectWithKey(secretKey);
    } catch (e) {
      AppLogger.error('Secret key save failed', error: e);
      setState(() {
        _errorMessage = l10n.secretKeySaveFailed(e.runtimeType.toString());
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 秘密鍵を指定して自動接続（Tor対応）
  Future<void> _autoConnectWithKey(String secretKey) async {
    final l10n = AppLocalizations.of(context);
    if (secretKey.isEmpty) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      // Initialise from the persisted settings, not from the in-memory relay
      // status map: that map is empty on a cold start, and falling back to
      // the public defaults here is how a user's own relay got replaced
      // (issue #193). Null means no relay was ever saved: first start.
      final relayList = startupRelaysFromSaved(
        await localStorageService.loadAppSettings(),
      );

      // アプリ設定からTor/プロキシ設定を取得
      final appSettingsAsync = ref.read(appSettingsProvider);
      final proxyUrl = appSettingsAsync.maybeWhen(
        data: (settings) {
          // Orbotモード時のみプロキシURLを使用
          return settings.torMode == TorMode.orbot ? settings.proxyUrl : null;
        },
        orElse: () => null,
      );

      if (relayList == null) {
        // 初回起動（リレー未保存）: デフォルトリレーを使用
        await nostrService.initializeNostr(
          secretKey: secretKey,
          proxyUrl: proxyUrl,
        );
      } else {
        await nostrService.initializeNostr(
          secretKey: secretKey,
          relays: relayList,
          proxyUrl: proxyUrl,
        );
      }

      setState(() {
        final l10n = AppLocalizations.of(context);
        _successMessage = proxyUrl != null
            ? l10n.connectedToRelayViaTor
            : l10n.connectedToRelay;
      });

      // 自動同期を実行
      await _autoSync();
    } catch (e) {
      AppLogger.error('Relay connection failed', error: e);
      setState(() {
        _errorMessage = l10n.relayConnectionError(e.runtimeType.toString());
      });
    }
  }

  /// 自動同期（バックグラウンド）
  Future<void> _autoSync() async {
    try {
      final todoNotifier = ref.read(todosProvider.notifier);

      // 新実装（Kind 30001）: Nostrから全Todoリストを同期
      await todoNotifier.syncFromNostr();

      AppLogger.debug('✅ Auto sync completed');
    } catch (e) {
      AppLogger.debug('❌ Auto sync failed: $e');
      // エラーは表示しない（バックグラウンド同期のため）
    }
  }

  /// ログアウト処理（全データ削除）
  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);

    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(dialogL10n.logout),
          content: Text(
            '${dialogL10n.logoutConfirm}\n\n${dialogL10n.logoutDescription}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogL10n.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(dialogL10n.logout),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      AppLogger.debug('🗑️ Starting complete data deletion...');

      // STEP 1: 先に進行中の同期/購読/ポーリングを止め、書き戻しゲートを閉じる。
      // クリア処理中に新しいイベントが書き戻されると残存データが復活するため、
      // 削除より前に必ず停止する。`nostrInitializedProvider = false` は
      // todosProvider 等のバックフィル/書き込みパスのゲートを閉じる役割。
      await _stopBackgroundActivity();
      _resetAllProviders();
      AppLogger.debug('✅ Background activity stopped & providers reset');

      // STEP 2: Rust プロセス上に常駐している機微情報を破棄する。
      // - NOSTR_CLIENTS (各クライアントが保持する Keys/SecretKey, ws 接続)
      // - mls::STORE (MlsUser のグループ秘密 + SQLite Connection)
      // mls::STORE が保持する Connection を解放してから物理ファイル削除する
      // ことで、unlink 中も書き込みが続いて secret が増殖する状態を避ける。
      await _clearRustSessionState();

      // STEP 3: Rust 側の暗号化された秘密鍵 / 公開鍵ファイルを削除。
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.deleteSecretKey();
      AppLogger.debug('✅ Secret key deleted (Rust)');

      // STEP 4: Hive 全ボックス（todos / settings / custom_lists）を削除。
      // .clear() ではなく box ファイルそのものを削除して、append-only な
      // 旧フレームから機微データが復元できないようにする。
      await localStorageService.clearAllData();
      AppLogger.debug(
        '✅ Hive boxes deleted (todos / settings / custom_lists)',
      );

      // STEP 4.5: タスクコメント box(task_comments)も物理削除する。
      // clearAllData() は LocalStorageService 管轄の box のみ対象で、
      // task_comments box は task_comments feature が独自に開くため
      // ここで個別に消さないと復号済みコメントが旧 user のまま残る。
      await ref
          .read(task_comment_providers.taskCommentLocalDataSourceProvider)
          .wipe();
      AppLogger.debug('✅ Task comment box deleted (task_comments)');

      // STEP 4.5b: the per-thread read watermarks (task_comment_read_state)
      // live in their own box and would otherwise survive logout and
      // pre-mark the next user's threads as read.
      await ref
          .read(
            task_comment_read_state_providers
                .taskCommentReadStateDataSourceProvider,
          )
          .wipe();
      AppLogger.debug(
        '✅ Task comment read-state box deleted (task_comment_read_state)',
      );

      // STEP 4.6: Also physically delete the send-outbox box (send_outbox).
      // If this retry queue survived logout, the first flush after the next
      // login would republish events signed by the previous user's key.
      await ref
          .read(send_outbox_providers.outboxLocalDataSourceProvider)
          .wipe();
      AppLogger.debug('✅ Send outbox box deleted (send_outbox)');

      // Re-arm the trigger now, bound to the fresh service STEP 1 just
      // invalidated. Without this read, `sendOutboxTriggerProvider` stays
      // dormant on its stale (disposed) service until something next
      // watches it — e.g. a comment screen — so resume/relay-connect edges
      // between now and then would silently no-op.
      ref.read(send_outbox_providers.sendOutboxTriggerProvider);

      // STEP 5: Nostr イベントキャッシュをクリア。
      await _clearNostrEventCache();

      // STEP 6: SharedPreferences の手動メディアサーバ一覧を削除。
      await _clearManualMediaServers();

      // STEP 7: アプリドキュメント領域に残っている MLS データベースを削除。
      await _deleteMlsDatabase();

      // STEP 8: 入力フィールドをクリアし、暗号化フラグをリセット
      _secretKeyController.clear();
      if (mounted) {
        setState(() {
          _hasEncryptedKey = false;
        });
      }

      AppLogger.debug('✅ Logout and data deletion completed');

      // STEP 9: オンボーディング画面に遷移（mounted チェック）
      if (!mounted) return;

      // GoRouterでオンボーディング画面に遷移
      context.go('/onboarding');
    } catch (e) {
      AppLogger.debug('❌ Logout failed: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = l10n.logoutFailed(e.toString());
        _isLoading = false;
      });
    }
  }

  /// 同期/購読/ポーリングを停止する。
  ///
  /// ログアウト中にバックグラウンド同期が走ると、せっかくクリアしたボックスに
  /// 古い user 由来のイベントが書き戻され「再同期される」と感じる原因になるため、
  /// データ削除の前に必ず止める。失敗してもログアウト全体は継続する。
  Future<void> _stopBackgroundActivity() async {
    try {
      await rust_api.stopAllSubscriptions();
      AppLogger.debug('✅ Stopped all Nostr subscriptions');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to stop subscriptions during logout: $e');
    }

    try {
      final amber = ref.read(amberServiceProvider);
      amber.stopListening();
      AppLogger.debug('✅ Stopped Amber EventChannel listening');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to stop Amber listener during logout: $e');
    }
  }

  /// Rust プロセス上の常駐機微情報（NOSTR_CLIENTS / mls::STORE）を破棄する。
  ///
  /// 失敗しても Hive / ファイル削除のステップは続行する（部分的なクリアでも
  /// やらないより安全)。
  Future<void> _clearRustSessionState() async {
    try {
      await rust_api.clearAllSessionState();
      AppLogger.debug(
        '✅ Rust session state cleared (NOSTR_CLIENTS, MLS STORE)',
      );
    } catch (e) {
      AppLogger.warning(
        '⚠️ Failed to clear Rust session state during logout: $e',
      );
    }
  }

  /// Nostr イベントキャッシュ（Hive box: nostr_event_cache）をクリアする。
  Future<void> _clearNostrEventCache() async {
    try {
      final cacheService = ref.read(nostrCacheServiceProvider);
      // init は前のセッションで完了している前提だが、念のため await。
      await cacheService.init();
      await cacheService.clearCache();
      AppLogger.debug('✅ Nostr event cache cleared');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to clear Nostr cache during logout: $e');
    }
  }

  /// 手動登録のメディアサーバ一覧（SharedPreferences: manual_media_servers）を削除する。
  Future<void> _clearManualMediaServers() async {
    try {
      final discovery = ref.read(mediaServerDiscoveryServiceProvider);
      await discovery.clearManualServers();
      AppLogger.debug('✅ Manual media servers cleared');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to clear manual media servers: $e');
    }
  }

  /// アプリドキュメント領域の MLS SQLite データベース（および付帯ファイル）を削除する。
  ///
  /// MLS のグループ状態は Hive ではなく `<app_doc_dir>/mls.db` にあるため、
  /// `clearAllData()` では消えない。再ログイン時に旧 user の招待状態などが
  /// 再表示されないよう、ここで明示的に削除する。
  ///
  /// 付帯ファイル (`-journal` / `-wal` / `-shm`) に加えて `.bak` も対象。
  /// `.bak` は MLS バックアップ復元 (`api.rs::import_mls_database_*`) が
  /// インポート前の旧 DB を退避するために生成するもので、削除し忘れると
  /// 旧 user の MLS グループ秘密がそのまま残る。
  Future<void> _deleteMlsDatabase() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      // ベースファイル + 付帯ファイル + 退避ファイルをまとめて消す。
      const targets = [
        '', // mls.db 本体
        '-journal',
        '-wal',
        '-shm',
        '.bak', // import_mls_database_* が生成する退避ファイル
      ];
      for (final suffix in targets) {
        final f = File('${appDocDir.path}/mls.db$suffix');
        if (await f.exists()) {
          await f.delete();
          AppLogger.debug('✅ Deleted MLS file: ${f.path}');
        }
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to delete MLS database during logout: $e');
    }
  }

  /// ログアウト時に必ずリセットするべきメモリ上の Provider をまとめてリセット。
  ///
  /// 個別に列挙しているのは「無関係な provider まで invalidate して
  /// 再生成コストを払いたくない」「StateProvider は invalidate よりも
  /// notifier.state = 初期値 のほうが意図が明確」という理由から。
  void _resetAllProviders() {
    // データ系
    ref.invalidate(todosProvider);
    ref.invalidate(customListsProvider);
    ref.invalidate(appSettingsProvider);
    ref.invalidate(bootstrapSyncProvider);
    ref.invalidate(syncStatusProvider);
    ref.invalidate(relayStatusProvider);
    ref.invalidate(mediaServersProvider);
    // Cancels the retry timer bound to the about-to-be-wiped queue, before
    // STEP 4.6 deletes its box out from under it.
    ref.invalidate(send_outbox_providers.sendOutboxServiceProvider);

    // 認証/接続状態
    ref.read(nostrInitializedProvider.notifier).state = false;
    ref.read(publicKeyProvider.notifier).state = null;
    ref.read(nostrPrivateKeyProvider.notifier).state = null;
    ref.read(nostrPublicKeyProvider.notifier).state = null;
  }

  void _copyToClipboard(String text, String label) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.copiedToClipboard(label))),
    );
  }

  Widget _buildTechBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final publicKeyHex = ref.watch(publicKeyProvider);
    final publicKeyNpubAsync = ref.watch(publicKeyNpubProvider);
    final isAmberMode = ref.watch(isAmberModeProvider);

    // デバッグログ: ログアウトボタン表示条件を確認
    AppLogger.debug('🔍 SecretKeyManagementScreen build:');
    AppLogger.debug('  isNostrInitialized: $isNostrInitialized');
    AppLogger.debug(
      '  publicKeyHex: ${publicKeyHex?.substring(0, 16) ?? 'null'}',
    );
    AppLogger.debug('  isAmberMode: $isAmberMode');
    AppLogger.debug('  ログアウトボタン表示: $isNostrInitialized');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).secretKeyManagementTitle),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 公開鍵表示カード（接続中の場合）
                  // 背景は半透明グリーンにして、ライト/ダーク双方で
                  // 文字（テーマ追従色）の視認性を確保する。
                  if (isNostrInitialized && publicKeyHex != null)
                    Card(
                      elevation: 0,
                      color: Colors.green.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 32,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isAmberMode
                                  ? l10n.loggingInAmber
                                  : l10n.nostrConnectedStatus,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            publicKeyNpubAsync.when(
                              data: (npubKey) => npubKey != null
                                  ? Column(
                                      children: [
                                        Text(
                                          'npub: ${npubKey.substring(0, 16)}...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'hex: ${publicKeyHex.substring(0, 12)}...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _copyToClipboard(
                                                npubKey,
                                                'npub',
                                              ),
                                              icon: const Icon(
                                                Icons.copy,
                                                size: 16,
                                              ),
                                              label: Text(l10n.copyNpub),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _copyToClipboard(
                                                publicKeyHex,
                                                'hex',
                                              ),
                                              icon: const Icon(
                                                Icons.copy,
                                                size: 16,
                                              ),
                                              label: Text(l10n.copyHex),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Text(
                                      l10n.publicKeyHexPrefix(
                                        publicKeyHex.substring(0, 16),
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                              loading: () => const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, __) => Text(
                                l10n.publicKeyHexPrefix(
                                  publicKeyHex.substring(0, 16),
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // エラー/成功メッセージ
                  if (_errorMessage != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                  if (_successMessage != null)
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 秘密鍵入力（Amberモードでは非表示）
                  if (!isAmberMode) ...[
                    Text(
                      l10n.secretKeyLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _secretKeyController,
                      // 暗号化プレースホルダーの場合は読み取り専用
                      readOnly:
                          _hasEncryptedKey &&
                          _secretKeyController.text == _encryptedPlaceholder,
                      decoration: InputDecoration(
                        hintText: l10n.secretKeyHint,
                        helperText: _detectedKeyFormatKind != null
                            ? l10n.secretKeyDetectedFormat(
                                _keyFormatLabel(
                                  l10n,
                                  _detectedKeyFormatKind!,
                                  hexLength: _detectedHexLength,
                                ),
                              )
                            : (_hasEncryptedKey &&
                                      _secretKeyController.text ==
                                          _encryptedPlaceholder
                                  ? l10n.secretKeyTapEyeToShow
                                  : l10n.secretKeyEnterFormat),
                        helperStyle: TextStyle(
                          color:
                              _detectedKeyFormatKind ==
                                      _KeyFormat.nsecIncomplete ||
                                  _detectedKeyFormatKind == _KeyFormat.unknown
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSecretKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _handleVisibilityToggle,
                          tooltip:
                              _hasEncryptedKey &&
                                  _secretKeyController.text ==
                                      _encryptedPlaceholder
                              ? l10n.secretKeyDecryptToShow
                              : (_obscureSecretKey
                                    ? l10n.secretKeyShow
                                    : l10n.secretKeyHide),
                        ),
                      ),
                      obscureText: _obscureSecretKey,
                      // パスワードマネージャ対応
                      autofillHints: const [AutofillHints.password],
                      keyboardType: TextInputType.visiblePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _generateNewSecretKey,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.generateButton),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveSecretKey,
                            icon: const Icon(Icons.save),
                            label: Text(l10n.saveAndConnect),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Amberモード情報
                  if (isAmberMode)
                    SettingsInfoCard(
                      icon: Icons.security,
                      title: l10n.amberModeTitle,
                      body: l10n.amberModeInfo,
                    ),
                  if (isAmberMode) const SizedBox(height: 16),

                  // ログアウトボタン
                  if (isNostrInitialized)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(
                        l10n.logout,
                        style: const TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // 注意事項（Amberモードでは非表示）
                  if (!isAmberMode) ...[
                    SettingsInfoCard(
                      icon: Icons.info,
                      title: l10n.importantTitle,
                      body: l10n.secretKeyImportantInfo,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 使用している暗号技術
                  Card(
                    color: AppTheme.sectionCardColor(context),
                    elevation: 2,
                    child: InkWell(
                      onTap: () =>
                          context.push('/settings/secret-key/cryptography'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.security,
                                    color: AppTheme.primaryPurple,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.cryptographyInUse,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.cryptographyDetailsDescription,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTechBadge(context, 'Argon2id'),
                                _buildTechBadge(context, 'AES-256-GCM'),
                                _buildTechBadge(context, 'NIP-44'),
                                _buildTechBadge(context, 'Ed25519'),
                                _buildTechBadge(context, 'Amber'),
                                _buildTechBadge(context, 'Rust'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
