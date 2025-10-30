import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/local_storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _secretKeyController = TextEditingController();
  final _newRelayController = TextEditingController();
  bool _isLoading = false;
  bool _obscureSecretKey = true;
  String? _errorMessage;
  String? _successMessage;
  String? _detectedKeyFormat; // 検出されたフォーマット (nsec/hex)

  @override
  void initState() {
    super.initState();
    // 暗号化された秘密鍵は自動読み込みしない（パスワードが必要）
    
    // ウィジェットツリーのビルドが完了してからProviderを変更
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRelayStates();
    });
    
    // テキスト変更時にフォーマットを自動検出
    _secretKeyController.addListener(_detectKeyFormat);
  }

  @override
  void dispose() {
    // セキュリティ: メモリから秘密鍵をクリア
    _secretKeyController.text = '';
    _secretKeyController.dispose();
    _newRelayController.dispose();
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

  void _initializeRelayStates() {
    final relayNotifier = ref.read(relayStatusProvider.notifier);
    
    // AppSettingsからリレーリストを取得（保存されている場合）
    final appSettings = ref.read(appSettingsProvider);
    appSettings.whenData((settings) {
      if (settings.relays.isNotEmpty) {
        // 保存されたリレーリストを使用
        relayNotifier.initializeWithRelays(settings.relays);
        print('✅ 保存されたリレーリストを読み込み: ${settings.relays.length}件');
      } else {
        // デフォルトリレーを使用
        relayNotifier.initializeWithRelays(defaultRelays);
        print('✅ デフォルトリレーを使用');
      }
    });
  }

  /// 秘密鍵のフォーマットを自動検出
  void _detectKeyFormat() {
    final key = _secretKeyController.text.trim();
    
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
      // より詳細なBech32バリデーションは省略（Rust側でチェック）
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
      _secretKeyController.text = newKey;
      
      // Rust APIで暗号化して保存
      await nostrService.saveSecretKey(newKey, password);

      setState(() {
        _successMessage = '新しい秘密鍵を生成して暗号化保存しました';
      });
      
      // 自動的にリレーに接続
      await _autoConnect();
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

      setState(() {
        _successMessage = '秘密鍵を暗号化保存しました（${_detectedKeyFormat ?? 'フォーマット不明'}）';
      });

      // 自動的にリレーに接続
      await _autoConnect();
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

  /// 秘密鍵設定後に自動接続
  Future<void> _autoConnect() async {
    final secretKey = _secretKeyController.text.trim();
    if (secretKey.isEmpty) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final relayList = ref.read(relayStatusProvider).keys.toList();
      
      if (relayList.isEmpty) {
        // デフォルトリレーを使用
        await nostrService.initializeNostr(secretKey: secretKey);
      } else {
        await nostrService.initializeNostr(
          secretKey: secretKey,
          relays: relayList,
        );
      }

      setState(() {
        _successMessage = 'リレーに接続しました';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'リレー接続エラー: $e';
      });
    }
  }

  /// リレーに接続（Amberモード対応）
  Future<void> _connectToRelays() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final publicKey = ref.read(nostrPublicKeyProvider);
      final secretKey = _secretKeyController.text.trim();
      final relayList = ref.read(relayStatusProvider).keys.toList();

      // Amberモード（公開鍵のみ）の場合
      if (publicKey != null && publicKey.isNotEmpty && secretKey.isEmpty) {
        print('🔗 Connecting to relays in Amber mode...');
        
        if (relayList.isEmpty) {
          // デフォルトリレーを使用
          await nostrService.initializeNostrWithPubkey(publicKeyHex: publicKey);
        } else {
          await nostrService.initializeNostrWithPubkey(
            publicKeyHex: publicKey,
            relays: relayList,
          );
        }
        
        setState(() {
          _successMessage = 'リレーに接続しました（Amberモード）';
        });
      } 
      // 秘密鍵モードの場合
      else if (secretKey.isNotEmpty) {
        print('🔗 Connecting to relays with secret key...');
        
        if (relayList.isEmpty) {
          await nostrService.initializeNostr(secretKey: secretKey);
        } else {
          await nostrService.initializeNostr(
            secretKey: secretKey,
            relays: relayList,
          );
        }
        
        setState(() {
          _successMessage = 'リレーに接続しました';
        });
      } else {
        setState(() {
          _errorMessage = '秘密鍵または公開鍵（Amber）が必要です';
        });
      }
    } catch (e) {
      print('❌ Failed to connect to relays: $e');
      setState(() {
        _errorMessage = 'リレー接続エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncTodos() async {
    if (!ref.read(nostrInitializedProvider)) {
      setState(() {
        _errorMessage = 'Nostrが初期化されていません';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final todoNotifier = ref.read(todosProvider.notifier);
      
      // 1. ローカルの未送信Todoをアップロード
      await todoNotifier.uploadPendingTodos();
      
      // 2. Nostrから最新のTodoをダウンロード
      final nostrService = ref.read(nostrServiceProvider);
      final todos = await nostrService.syncTodosFromNostr();
      await todoNotifier.mergeTodosFromNostr(todos);

      setState(() {
        _successMessage = '${todos.length}件のTodoをダウンロードし、未送信Todoをアップロードしました';
      });
    } catch (e) {
      setState(() {
        _errorMessage = '同期エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addRelay() {
    final url = _newRelayController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
      setState(() {
        _errorMessage = 'リレーURLは wss:// または ws:// で始まる必要があります';
      });
      return;
    }

    ref.read(relayStatusProvider.notifier).addRelay(url);
    _newRelayController.clear();
    
    // AppSettingsにも反映
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
    
    setState(() {
      _successMessage = 'リレーを追加しました';
    });

    // 接続済みの場合は新しいリレーにも接続
    if (ref.read(nostrInitializedProvider)) {
      _autoConnect();
    }
  }

  void _removeRelay(String url) {
    ref.read(relayStatusProvider.notifier).removeRelay(url);
    
    // AppSettingsにも反映
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
    
    setState(() {
      _successMessage = 'リレーを削除しました';
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$labelをコピーしました')),
    );
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
      
      // 4. 入力フィールドをクリア
      _secretKeyController.clear();
      
      print('✅ Logout and data deletion completed');
      
      // 5. オンボーディング画面に遷移（mounted チェック）
      if (!mounted) return;
      
      // GoRouterでオンボーディング画面に遷移
      // redirectロジックが自動で働く
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

  @override
  Widget build(BuildContext context) {
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final publicKeyHex = ref.watch(publicKeyProvider);
    final publicKeyNpubAsync = ref.watch(publicKeyNpubProvider);
    final relayStatuses = ref.watch(relayStatusProvider);
    final isAmberMode = ref.watch(isAmberModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ステータスカード
                  Card(
                    color: isNostrInitialized
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            isNostrInitialized ? Icons.check_circle : Icons.warning,
                            size: 48,
                            color: isNostrInitialized
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isNostrInitialized
                                ? (isAmberMode ? 'Nostr接続中 (Amber)' : 'Nostr接続中')
                                : 'Nostr未接続',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (isNostrInitialized && publicKeyHex != null) ...[
                            const SizedBox(height: 8),
                            publicKeyNpubAsync.when(
                              data: (npubKey) => npubKey != null
                                  ? Column(
                                      children: [
                                        Text(
                                          'npub: ${npubKey.substring(0, 16)}...',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'hex: ${publicKeyHex.substring(0, 12)}...',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey,
                                              ),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _copyToClipboard(npubKey, 'npub公開鍵'),
                                              icon: const Icon(Icons.copy, size: 16),
                                              label: const Text('npubコピー'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _copyToClipboard(publicKeyHex, 'hex公開鍵'),
                                              icon: const Icon(Icons.copy, size: 16),
                                              label: const Text('hexコピー'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '公開鍵: ${publicKeyHex.substring(0, 16)}...',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                              loading: () => const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (_, __) => Text(
                                '公開鍵: ${publicKeyHex.substring(0, 16)}...',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

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

                  // 秘密鍵セクション
                  Text(
                    '秘密鍵',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _secretKeyController,
                    decoration: InputDecoration(
                      hintText: 'nsec1... または 64文字のhex',
                      helperText: _detectedKeyFormat != null 
                          ? '検出: $_detectedKeyFormat'
                          : 'nsecまたはhex形式の秘密鍵を入力',
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
                          _obscureSecretKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureSecretKey = !_obscureSecretKey;
                          });
                        },
                        tooltip: _obscureSecretKey ? '秘密鍵を表示' : '秘密鍵を非表示',
                      ),
                    ),
                    obscureText: _obscureSecretKey,
                    maxLines: 1,
                    // パスワードマネージャ対応（KeePass等からの入力を可能に）
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
                  const SizedBox(height: 8),
                  // リレーに接続ボタン（Amber対応）
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _connectToRelays,
                      icon: const Icon(Icons.link),
                      label: const Text('リレーに接続'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // リレーセクション
                  Text(
                    'リレーサーバー',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  
                  // リレー追加
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newRelayController,
                          decoration: const InputDecoration(
                            hintText: 'wss://relay.example.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addRelay,
                        icon: const Icon(Icons.add_circle),
                        tooltip: 'リレーを追加',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // リレーリスト
                  if (relayStatuses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'リレーが登録されていません',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    )
                  else
                    ...relayStatuses.values.map((relay) => Card(
                          child: ListTile(
                            leading: _buildRelayStatusIcon(relay.state),
                            title: Text(
                              relay.url,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: relay.errorMessage != null
                                ? Text(
                                    relay.errorMessage!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade700,
                                    ),
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _removeRelay(relay.url),
                              tooltip: '削除',
                            ),
                          ),
                        )),
                  
                  const SizedBox(height: 24),

                  // 手動同期ボタン
                  ElevatedButton.icon(
                    onPressed: _isLoading || !isNostrInitialized ? null : _syncTodos,
                    icon: const Icon(Icons.sync),
                    label: const Text('手動同期'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

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

                  // アプリ設定セクション（NIP-78 - Kind 30078でNostrに保存）
                  _buildAppSettingsSection(),
                  const SizedBox(height: 24),

                  // 注意事項
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
                ],
              ),
            ),
    );
  }

  /// リレー状態アイコン
  Widget _buildRelayStatusIcon(RelayConnectionState state) {
    switch (state) {
      case RelayConnectionState.connected:
        // 接続中は同期マークを表示（Todoアイテムと同じアイコン）
        return Icon(Icons.cloud_done, color: Colors.green.shade400, size: 20);
      case RelayConnectionState.connecting:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
          ),
        );
      case RelayConnectionState.error:
        return Icon(Icons.error, color: Colors.red.shade600, size: 20);
      case RelayConnectionState.disconnected:
        return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
    }
  }

  /// アプリ設定セクション（NIP-78 - Kind 30078でNostrに保存）
  Widget _buildAppSettingsSection() {
    final appSettingsAsync = ref.watch(appSettingsProvider);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_applications, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  'アプリ設定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isNostrInitialized)
                  Icon(
                    Icons.cloud,
                    size: 16,
                    color: Colors.purple.shade300,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isNostrInitialized
                  ? 'Nostrリレーに自動同期（NIP-78 Kind 30078）'
                  : 'ローカル保存のみ（Nostr未接続）',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const Divider(height: 24),
            
            appSettingsAsync.when(
              data: (settings) => Column(
                children: [
                  // ダークモード設定
                  SwitchListTile(
                    title: const Text('ダークモード'),
                    subtitle: const Text('アプリのテーマを変更'),
                    value: settings.darkMode,
                    onChanged: (value) async {
                      await ref.read(appSettingsProvider.notifier).toggleDarkMode();
                    },
                    secondary: Icon(
                      settings.darkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  
                  const Divider(),
                  
                  // 週の開始曜日
                  ListTile(
                    leading: Icon(Icons.calendar_today, color: Colors.purple.shade700),
                    title: const Text('週の開始曜日'),
                    subtitle: Text(_getWeekDayName(settings.weekStartDay)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showWeekStartDayDialog(settings.weekStartDay),
                  ),
                  
                  const Divider(),
                  
                  // カレンダー表示形式
                  ListTile(
                    leading: Icon(Icons.view_week, color: Colors.purple.shade700),
                    title: const Text('カレンダー表示'),
                    subtitle: Text(settings.calendarView == 'week' ? '週表示' : '月表示'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showCalendarViewDialog(settings.calendarView),
                  ),
                  
                  const Divider(),
                  
                  // 通知設定
                  SwitchListTile(
                    title: const Text('通知'),
                    subtitle: const Text('リマインダー通知を有効化'),
                    value: settings.notificationsEnabled,
                    onChanged: (value) async {
                      await ref.read(appSettingsProvider.notifier).toggleNotifications();
                    },
                    secondary: Icon(
                      settings.notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  
                  if (isNostrInitialized) ...[
                    const Divider(),
                    
                    // 同期ボタン
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(appSettingsProvider.notifier).syncFromNostr();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('設定を同期しました')),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Nostrから同期'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade100,
                          foregroundColor: Colors.purple.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('エラー: $error'),
            ),
          ],
        ),
      ),
    );
  }

  /// 曜日名を取得
  String _getWeekDayName(int day) {
    const days = ['日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日'];
    return days[day % 7];
  }

  /// 週の開始曜日選択ダイアログ
  Future<void> _showWeekStartDayDialog(int currentDay) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('週の開始曜日を選択'),
        children: List.generate(7, (index) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, index),
            child: Text(
              _getWeekDayName(index),
              style: TextStyle(
                fontWeight: index == currentDay ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ),
    );

    if (selected != null) {
      await ref.read(appSettingsProvider.notifier).setWeekStartDay(selected);
    }
  }

  /// カレンダー表示形式選択ダイアログ
  Future<void> _showCalendarViewDialog(String currentView) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('カレンダー表示を選択'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'week'),
            child: Text(
              '週表示',
              style: TextStyle(
                fontWeight: currentView == 'week' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'month'),
            child: Text(
              '月表示',
              style: TextStyle(
                fontWeight: currentView == 'month' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (selected != null) {
      await ref.read(appSettingsProvider.notifier).setCalendarView(selected);
    }
  }
}
