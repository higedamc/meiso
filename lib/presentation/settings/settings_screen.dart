import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/relay_status_provider.dart';

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
    _loadSecretKey();
    _initializeRelayStates();
    
    // テキスト変更時にフォーマットを自動検出
    _secretKeyController.addListener(_detectKeyFormat);
  }

  @override
  void dispose() {
    _secretKeyController.dispose();
    _newRelayController.dispose();
    super.dispose();
  }

  Future<void> _loadSecretKey() async {
    final nostrService = ref.read(nostrServiceProvider);
    final secretKey = await nostrService.getSecretKey();
    if (secretKey != null) {
      _secretKeyController.text = secretKey;
    }
  }

  void _initializeRelayStates() {
    final relayNotifier = ref.read(relayStatusProvider.notifier);
    relayNotifier.initializeWithRelays(defaultRelays);
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final newKey = await nostrService.generateNewSecretKey();
      _secretKeyController.text = newKey;
      await nostrService.saveSecretKey(newKey);

      setState(() {
        _successMessage = '新しい秘密鍵を生成しました';
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.saveSecretKey(secretKey);

      setState(() {
        _successMessage = '秘密鍵を保存しました（${_detectedKeyFormat ?? 'フォーマット不明'}）';
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

  @override
  Widget build(BuildContext context) {
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final publicKeyHex = ref.watch(publicKeyProvider);
    final publicKeyNpubAsync = ref.watch(publicKeyNpubProvider);
    final relayStatuses = ref.watch(relayStatusProvider);

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
                                ? 'Nostr接続中'
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
                  const SizedBox(height: 24),

                  // 注意事項
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '重要',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• 秘密鍵は安全に保管してください\n'
                            '• 秘密鍵を紛失するとデータを復元できません\n'
                            '• 秘密鍵を保存すると自動的にリレーに接続します\n'
                            '• タスクの変更は自動的にリレーに同期されます\n\n'
                            '対応形式:\n'
                            '  • nsec形式: nsec1... (Bech32エンコード)\n'
                            '  • hex形式: 64文字の16進数',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
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
        return Icon(Icons.check_circle, color: Colors.green.shade600, size: 20);
      case RelayConnectionState.connecting:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
        );
      case RelayConnectionState.error:
        return Icon(Icons.error, color: Colors.red.shade600, size: 20);
      case RelayConnectionState.disconnected:
        return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
    }
  }
}
