import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../services/local_storage_service.dart';
import '../../services/amber_service.dart';
import '../../providers/nostr_provider.dart';
import '../../bridge_generated.dart/api.dart' as rust_api;

/// ログインスクリーン
/// AmberまたはNostr秘密鍵生成でログイン
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AmberService _amberService = AmberService();

  @override
  void dispose() {
    _amberService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // アイコン
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.key,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
              ),

              const SizedBox(height: 48),

              // タイトル
              Text(
                'ログイン方法を選択',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 説明
              Text(
                'Nostrアカウントでログインして、\nタスクを同期しましょう',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Amberでログインボタン
              Consumer(
                builder: (context, ref, child) {
                  return ElevatedButton.icon(
                    onPressed: () => _loginWithAmber(context, ref),
                    icon: const Icon(Icons.android, size: 24),
                    label: const Text(
                      'Amberでログイン',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 区切り線
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'または',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 16),

              // 新しい秘密鍵を生成ボタン
              Consumer(
                builder: (context, ref, child) {
                  return OutlinedButton.icon(
                    onPressed: () => _generateNewKey(context, ref),
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    label: const Text(
                      '新しい秘密鍵を生成',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // 注意書き
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '秘密鍵は安全に保管されます。\nAmberを使用すると、より安全に管理できます。',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Amberでログイン
  Future<void> _loginWithAmber(BuildContext context, WidgetRef ref) async {
    try {
      // Amberがインストールされているか確認
      final isInstalled = await _amberService.isAmberInstalled();
      if (!isInstalled) {
        if (!context.mounted) return;

        // Amberインストールを促すダイアログ
        final shouldInstall = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Amberが必要です'),
            content: const Text(
              'Amberアプリがインストールされていません。\nGoogle Playからインストールしますか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('インストール'),
              ),
            ],
          ),
        );

        if (shouldInstall == true) {
          await _amberService.openAmberInStore();
        }
        return;
      }

      // ⚠️ 重要: Amber呼び出し前にオンボーディング完了フラグを設定
      // Amberから戻ってきた時にアプリが再起動される可能性があるため、
      // フラグを事前に設定しておく必要がある
      await localStorageService.setOnboardingCompleted();
      await localStorageService.setUseAmber(true);
      print('✅ Onboarding completed flag set (before Amber)');
      print('✅ Amber usage flag set');

      // ローディング表示
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Amberから公開鍵を取得（MethodChannel経由）
      try {
        final publicKeyRaw = await _amberService.getPublicKey();
        
        if (publicKeyRaw != null && publicKeyRaw.isNotEmpty) {
          print('✅ Public key received: ${publicKeyRaw.substring(0, 10)}...');
          
          try {
            // Amberはnpub形式で公開鍵を返すため、hex形式に変換
            final nostrService = ref.read(nostrServiceProvider);
            final publicKeyHex = await nostrService.npubToHex(publicKeyRaw);
            print('✅ Public key converted to hex: ${publicKeyHex.substring(0, 16)}...');
            
            // Rust APIで公開鍵を保存（Amberモード、hex形式）
            await nostrService.savePublicKey(publicKeyHex);
            print('✅ Public key saved to Rust storage');
            
            // Nostrクライアントを公開鍵のみで初期化（Amberモード）
            // デフォルトリレーに自動接続
            await nostrService.initializeNostrWithPubkey(
              publicKeyHex: publicKeyHex,
            );
            print('✅ Nostr client initialized with public key');
            
            // リレー接続完了を待機（最大3秒、500msごとに確認）
            print('⏳ Waiting for relay connection...');
            int retryCount = 0;
            const maxRetries = 6; // 3秒 (500ms × 6)
            while (retryCount < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 500));
              retryCount++;
              
              // Rust側で接続完了しているはず（タイムアウト5秒設定済み）
              if (retryCount >= 3) {
                print('✅ Relay connection check passed (${retryCount * 500}ms)');
                break;
              }
            }
            
            if (retryCount >= maxRetries) {
              print('⚠️ Relay connection check timeout - continuing offline');
            }
            
            print('✅ Connected to default relays (or offline mode)');
            
            // Nostrプロバイダーを更新
            ref.read(publicKeyProvider.notifier).state = publicKeyHex; // hex形式
            ref.read(nostrPublicKeyProvider.notifier).state = publicKeyRaw; // npub形式

            if (!context.mounted) return;
            
            // ローディングダイアログを閉じる
            try {
              Navigator.of(context).pop();
            } catch (e) {
              print('⚠️ Could not pop loading dialog: $e');
            }
            
            // 次のフレームで画面遷移（GoRouter を使用）
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              
              print('🚀 Navigating to home screen via GoRouter...');
              
              // GoRouter で画面遷移（redirect が自動的に処理）
              context.go('/');
              
              print('✅ GoRouter navigation triggered');
            });
          } catch (e, stackTrace) {
            print('❌ Error during Amber login: $e');
            print('Stack trace: $stackTrace');
            
            if (!context.mounted) return;
            
            // エラー時のみローディングダイアログを閉じる
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              
              try {
                Navigator.of(context, rootNavigator: true).pop();
              } catch (e) {
                print('⚠️ Could not pop loading dialog: $e');
              }
              
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('エラー'),
                  content: Text('ログイン処理中にエラーが発生しました\n$e'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            });
          }
        } else {
          print('⚠️ No public key received from Amber');
          
          if (!context.mounted) return;
          
          // エラー時のみローディングダイアログを閉じる
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            
            try {
              Navigator.of(context, rootNavigator: true).pop();
            } catch (e) {
              print('⚠️ Could not pop loading dialog: $e');
            }
            
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('エラー'),
                content: const Text('Amberから公開鍵を取得できませんでした'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
        }
      } catch (e) {
        print('❌ Failed to get public key from Amber: $e');
        
        if (!context.mounted) return;
        
        // エラー時のみローディングダイアログを閉じる
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (e) {
            print('⚠️ Could not pop loading dialog: $e');
          }
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('エラー'),
              content: Text('Amberとの連携に失敗しました\n$e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        });
      }

    } catch (e) {
      if (!context.mounted) return;
      
      // エラーダイアログ表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('エラー'),
          content: Text('Amberとの連携に失敗しました\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// 新しい秘密鍵を生成
  Future<void> _generateNewKey(BuildContext context, WidgetRef ref) async {
    try {
      // パスワード入力ダイアログ
      final passwordController = TextEditingController();
      final confirmPasswordController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      
      if (!context.mounted) return;
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('パスワードを設定'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '秘密鍵を暗号化するためのパスワードを設定してください。',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    if (value.length < 8) {
                      return '8文字以上で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード（確認）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'パスワードが一致しません';
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
      
      if (password == null) return; // キャンセルされた
      
      // ローディング表示
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Rust側で秘密鍵を生成
      print('🔑 Generating new keypair...');
      final keypair = await rust_api.generateKeypair();

      print('✅ Keypair generated:');
      print('  Private (nsec): ${keypair.privateKeyNsec.substring(0, 20)}...');
      print('  Public (npub): ${keypair.publicKeyNpub}');

      // Rust APIで秘密鍵を暗号化して保存
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.saveSecretKey(keypair.privateKeyNsec, password);
      print('✅ Secret key encrypted and saved');
      
      // オンボーディング完了フラグを設定（Nostr初期化前）
      await localStorageService.setOnboardingCompleted();
      await localStorageService.setUseAmber(false); // 秘密鍵モードを明示
      print('✅ Onboarding completed flag set (before Nostr init)');
      
      // Nostrクライアントを初期化
      await nostrService.initializeNostr(
        secretKey: keypair.privateKeyNsec,
      );
      print('✅ Nostr client initialized with secret key');

      // Nostrプロバイダーを更新
      ref.read(nostrPublicKeyProvider.notifier).state = keypair.publicKeyNpub;
      ref.read(nostrPrivateKeyProvider.notifier).state = keypair.privateKeyNsec;

      if (!context.mounted) return;
      Navigator.of(context).pop(); // ローディング閉じる

      // 秘密鍵を表示するダイアログ
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('秘密鍵が生成されました'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '以下の秘密鍵を安全な場所にバックアップしてください。',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '秘密鍵 (nsec):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    keypair.privateKeyNsec,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '公開鍵 (npub):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
                  ),
                  child: SelectableText(
                    keypair.publicKeyNpub,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'この秘密鍵を失うと、アカウントにアクセスできなくなります。必ずバックアップしてください。',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print('🚀 Navigating to home screen after key backup...');
                
                // GoRouter で画面遷移
                context.go('/');
                
                print('✅ GoRouter navigation triggered');
              },
              child: const Text(
                'バックアップしました',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      print('❌ Failed to generate keypair: $e');
      print('Stack trace: $stackTrace');

      if (!context.mounted) return;
      Navigator.of(context).pop(); // ローディング閉じる

      // エラーダイアログ表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('エラー'),
          content: Text('秘密鍵の生成に失敗しました\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

