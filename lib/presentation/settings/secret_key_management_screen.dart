import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/local_storage_service.dart';

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
  String? _detectedKeyFormat; // 検出されたフォーマット (nsec/hex)
  bool _hasEncryptedKey = false; // 暗号化された秘密鍵が存在するか
  static const String _encryptedPlaceholder = '🔒 暗号化されています';

  @override
  void initState() {
    super.initState();
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
      builder: (context) => AlertDialog(
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
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(passwordController.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// nsec表示ダイアログを表示
  Future<void> _showNsecDialog(String nsec) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.key, color: AppTheme.primaryPurple),
            const SizedBox(width: 8),
            const Text('秘密鍵 (nsec)'),
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
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ 重要な注意事項',
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
                '• 秘密鍵は絶対に他人に見せないでください\n'
                '• スクリーンショットは推奨しません\n'
                '• 秘密鍵を失うとアカウントを復元できません\n'
                '• 安全な場所にバックアップしてください',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '秘密鍵:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              // nsec表示エリア
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
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
              _copyToClipboard(nsec, '秘密鍵');
            },
            icon: const Icon(Icons.copy),
            label: const Text('コピー'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// 目のアイコンタップ時の処理
  Future<void> _handleVisibilityToggle() async {
    // 暗号化された秘密鍵が存在し、フィールドが暗号化プレースホルダーの場合
    if (_hasEncryptedKey && _secretKeyController.text == _encryptedPlaceholder) {
      // パスワード入力ダイアログを表示
      final password = await _showPasswordDialog(
        'パスワードを入力',
        '秘密鍵を復号するためのパスワードを入力してください。',
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
            _errorMessage = 'パスワードが間違っているか、秘密鍵の復号に失敗しました';
          });
          return;
        }

        // nsec表示ダイアログを表示（hex形式でもそのまま表示）
        if (mounted) {
          await _showNsecDialog(decryptedKey);
        }
      } catch (e) {
        setState(() {
          _errorMessage = '秘密鍵の復号に失敗: $e';
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
      if (_detectedKeyFormat != null) {
        setState(() {
          _detectedKeyFormat = null;
        });
      }
      return;
    }

    if (key.isEmpty) {
      if (_detectedKeyFormat != null) {
        setState(() {
          _detectedKeyFormat = null;
        });
      }
      return;
    }

    String? newFormat;

    if (key.startsWith('nsec1')) {
      // Bech32形式 (nsec)
      if (key.length >= 63) {
        newFormat = 'nsec (Bech32)';
      } else {
        newFormat = 'nsec (不完全)';
      }
    } else if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(key)) {
      // Hex形式
      if (key.length == 64) {
        newFormat = 'hex (64文字)';
      } else {
        newFormat = 'hex (${key.length}/64文字)';
      }
    } else {
      newFormat = '不明な形式';
    }

    if (_detectedKeyFormat != newFormat) {
      setState(() {
        _detectedKeyFormat = newFormat;
      });
    }
  }

  /// 秘密鍵のバリデーション
  String? _validateSecretKey(String key) {
    if (key.isEmpty) {
      return '秘密鍵を入力してください';
    }

    if (key.startsWith('nsec1')) {
      if (key.length < 63) {
        return 'nsec形式は63文字以上必要です';
      }
      return null;
    } else if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(key)) {
      if (key.length != 64) {
        return 'hex形式は64文字である必要があります（現在${key.length}文字）';
      }
      return null;
    } else {
      return '秘密鍵はnsec形式（nsec1...）またはhex形式（64文字の16進数）である必要があります';
    }
  }

  Future<void> _generateNewSecretKey() async {
    // パスワード入力
    final password = await _showPasswordDialog(
      'パスワードを設定',
      '新しい秘密鍵を暗号化するためのパスワードを設定してください。\n（8文字以上推奨）',
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
        _successMessage = '新しい秘密鍵を生成して暗号化保存しました';
      });

      // 自動的にリレーに接続（newKeyを使用）
      await _autoConnectWithKey(newKey);
    } catch (e) {
      setState(() {
        _errorMessage = '秘密鍵の生成に失敗: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSecretKey() async {
    final secretKey = _secretKeyController.text.trim();

    // 暗号化プレースホルダーの場合は保存をスキップ
    if (secretKey == _encryptedPlaceholder) {
      setState(() {
        _errorMessage = '暗号化された秘密鍵は既に保存されています';
      });
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
    final password = await _showPasswordDialog(
      'パスワードを設定',
      '秘密鍵を暗号化するためのパスワードを設定してください。\n（8文字以上推奨）',
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
        _successMessage =
            '秘密鍵を暗号化保存しました（${_detectedKeyFormat ?? 'フォーマット不明'}）';
      });

      // 自動的にリレーに接続（secretKeyを使用）
      await _autoConnectWithKey(secretKey);
    } catch (e) {
      setState(() {
        _errorMessage = '秘密鍵の保存に失敗: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 秘密鍵を指定して自動接続（Tor対応）
  Future<void> _autoConnectWithKey(String secretKey) async {
    if (secretKey.isEmpty) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final relayList = ref.read(relayStatusProvider).keys.toList();
      
      // アプリ設定からTor/プロキシ設定を取得
      final appSettingsAsync = ref.read(appSettingsProvider);
      final proxyUrl = appSettingsAsync.maybeWhen(
        data: (settings) => settings.torEnabled ? settings.proxyUrl : null,
        orElse: () => null,
      );

      if (relayList.isEmpty) {
        // デフォルトリレーを使用
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
        _successMessage = 'リレーに接続しました${proxyUrl != null ? " (Tor経由)" : ""}';
      });
      
      // 自動同期を実行
      await _autoSync();
    } catch (e) {
      setState(() {
        _errorMessage = 'リレー接続エラー: $e';
      });
    }
  }

  /// 自動同期（バックグラウンド）
  Future<void> _autoSync() async {
    try {
      final todoNotifier = ref.read(todosProvider.notifier);
      
      // 新実装（Kind 30001）: Nostrから全Todoリストを同期
      await todoNotifier.syncFromNostr();
      
      print('✅ Auto sync completed');
    } catch (e) {
      print('❌ Auto sync failed: $e');
      // エラーは表示しない（バックグラウンド同期のため）
    }
  }

  /// ログアウト処理（全データ削除）
  Future<void> _logout() async {
    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text(
          'ログアウトしますか？\n\n'
          '⚠️ 警告:\n'
          '• アプリ内の全データが削除されます\n'
          '• 全てのTodoが削除されます\n'
          '• 暗号化された秘密鍵が削除されます\n'
          '• 設定情報が削除されます\n\n'
          '秘密鍵とパスワードを記録していないと、'
          '再ログインできなくなります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('全て削除してログアウト'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      print('🗑️ Starting complete data deletion...');

      final nostrService = ref.read(nostrServiceProvider);

      // 1. Rust側の暗号化された鍵を削除
      await nostrService.deleteSecretKey();
      print('✅ Secret key deleted');

      // 2. アプリ内の全データを削除（Todo + 設定）
      await localStorageService.clearAllData();
      print('✅ All local data deleted');

      // 3. すべてのProviderをリセット
      ref.invalidate(todosProvider);
      ref.read(nostrInitializedProvider.notifier).state = false;
      ref.read(publicKeyProvider.notifier).state = null;
      ref.invalidate(relayStatusProvider);
      print('✅ All providers reset');

      // 4. 入力フィールドをクリアし、暗号化フラグをリセット
      _secretKeyController.clear();
      setState(() {
        _hasEncryptedKey = false;
      });

      print('✅ Logout and data deletion completed');

      // 5. オンボーディング画面に遷移（mounted チェック）
      if (!mounted) return;

      // GoRouterでオンボーディング画面に遷移
      context.go('/onboarding');
    } catch (e) {
      print('❌ Logout failed: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'ログアウト失敗: $e';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$labelをコピーしました')),
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
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.darkPurple,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final publicKeyHex = ref.watch(publicKeyProvider);
    final publicKeyNpubAsync = ref.watch(publicKeyNpubProvider);
    final isAmberMode = ref.watch(isAmberModeProvider);
    
    // デバッグログ: ログアウトボタン表示条件を確認
    print('🔍 SecretKeyManagementScreen build:');
    print('  isNostrInitialized: $isNostrInitialized');
    print('  publicKeyHex: ${publicKeyHex?.substring(0, 16) ?? 'null'}');
    print('  isAmberMode: $isAmberMode');
    print('  ログアウトボタン表示: ${isNostrInitialized}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('秘密鍵管理'),
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
                  if (isNostrInitialized && publicKeyHex != null)
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 32,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isAmberMode ? 'ログイン中 (Amber)' : 'Nostr接続中',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                                color: Colors.grey,
                                              ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _copyToClipboard(
                                                  npubKey, 'npub公開鍵'),
                                              icon: const Icon(Icons.copy,
                                                  size: 16),
                                              label: const Text('npubコピー'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _copyToClipboard(
                                                  publicKeyHex, 'hex公開鍵'),
                                              icon: const Icon(Icons.copy,
                                                  size: 16),
                                              label: const Text('hexコピー'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '公開鍵: ${publicKeyHex.substring(0, 16)}...',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                              loading: () => const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (_, __) => Text(
                                '公開鍵: ${publicKeyHex.substring(0, 16)}...',
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
                      '秘密鍵',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _secretKeyController,
                      // 暗号化プレースホルダーの場合は読み取り専用
                      readOnly: _hasEncryptedKey && _secretKeyController.text == _encryptedPlaceholder,
                      decoration: InputDecoration(
                        hintText: 'nsec1... または 64文字のhex',
                        helperText: _detectedKeyFormat != null
                            ? '検出: $_detectedKeyFormat'
                            : (_hasEncryptedKey && _secretKeyController.text == _encryptedPlaceholder
                                ? '目のアイコンをタップして秘密鍵を表示'
                                : 'nsecまたはhex形式の秘密鍵を入力'),
                        helperStyle: TextStyle(
                          color: _detectedKeyFormat?.contains('不完全') == true ||
                                  _detectedKeyFormat?.contains('不明') == true
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
                          tooltip: _hasEncryptedKey && _secretKeyController.text == _encryptedPlaceholder
                              ? '秘密鍵を復号して表示'
                              : (_obscureSecretKey ? '秘密鍵を表示' : '秘密鍵を非表示'),
                        ),
                      ),
                      obscureText: _obscureSecretKey,
                      maxLines: 1,
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
                            onPressed: _isLoading ? null : _generateNewSecretKey,
                            icon: const Icon(Icons.refresh),
                            label: const Text('生成'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveSecretKey,
                            icon: const Icon(Icons.save),
                            label: const Text('保存して接続'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Amberモード情報
                  if (isAmberMode)
                    Card(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.security, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  'Amberモード',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '✅ Amberモードで接続中\n\n'
                              '🔒 セキュリティ機能:\n'
                              '• Todoの作成・編集時にAmberで署名\n'
                              '• NIP-44暗号化でコンテンツを保護\n'
                              '• 秘密鍵はAmber内でncryptsec準拠で暗号化保存\n\n'
                              '⚡ 復号化の最適化:\n'
                              'Todoの同期時に復号化の承認が必要です。\n'
                              '毎回承認するのを避けるために、Amberアプリで\n'
                              '「Meisoアプリを常に許可」を設定することを推奨します。\n\n'
                              '📝 設定方法:\n'
                              '1. Amberアプリを開く\n'
                              '2. アプリ一覧から「Meiso」を選択\n'
                              '3. 「NIP-44 Decrypt」を常に許可に設定',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isAmberMode) const SizedBox(height: 16),

                  // ログアウトボタン
                  if (isNostrInitialized)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'ログアウト',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // 注意事項（Amberモードでは非表示）
                  if (!isAmberMode) ...[
                    Card(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  '重要',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• 秘密鍵はパスワードで暗号化されて保存されます\n'
                              '• パスワードと秘密鍵は安全に保管してください\n'
                              '• パスワードを忘れると秘密鍵を復元できません\n'
                              '• 秘密鍵を保存すると自動的にリレーに接続します\n'
                              '• タスクの変更は自動的にリレーに同期されます\n\n'
                              '対応形式:\n'
                              '  • nsec形式: nsec1... (Bech32エンコード)\n'
                              '  • hex形式: 64文字の16進数',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 使用している暗号技術
                  Card(
                    color: Colors.white,
                    elevation: 2,
                    child: InkWell(
                      onTap: () => context.push('/settings/secret-key/cryptography'),
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
                                    color: AppTheme.primaryPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.security,
                                    color: AppTheme.primaryPurple,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '使用している暗号技術',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.darkPurple,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Meisoで採用している暗号技術の詳細',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
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

