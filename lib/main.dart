import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_theme.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/onboarding/login_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/settings/secret_key_management_screen.dart';
import 'presentation/settings/relay_management_screen.dart';
import 'presentation/settings/app_settings_detail_screen.dart';
import 'bridge_generated.dart/frb_generated.dart';
import 'services/local_storage_service.dart';
import 'providers/app_settings_provider.dart';
import 'providers/nostr_provider.dart' as nostrProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 英語ロケール初期化
  await initializeDateFormatting('en_US');
  
  // ローカルストレージの初期化
  try {
    await localStorageService.initialize();
    print('✅ ローカルストレージ初期化成功');
  } catch (e) {
    print('❌ ローカルストレージ初期化エラー: $e');
  }
  
  // Rustブリッジの初期化（エラーハンドリング付き）
  try {
    await RustLib.init();
    print('✅ Rust初期化成功');
  } catch (e, stackTrace) {
    print('❌ Rust初期化エラー: $e');
    print('スタックトレース: $stackTrace');
    // エラーがあってもアプリは起動させる（Nostr機能なしで動作）
  }
  
  runApp(
    const ProviderScope(
      child: MeisoApp(),
    ),
  );
}

class MeisoApp extends ConsumerStatefulWidget {
  const MeisoApp({super.key});

  @override
  ConsumerState<MeisoApp> createState() => _MeisoAppState();
}

class _MeisoAppState extends ConsumerState<MeisoApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    
    // アプリのライフサイクル監視を開始
    WidgetsBinding.instance.addObserver(this);
    
    // アプリ起動時にNostr接続を復元
    _restoreNostrConnection();
    
    // GoRouterの初期化
    _router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final hasCompleted = localStorageService.hasCompletedOnboarding();
        final currentLocation = state.matchedLocation;
        final isOnboarding = currentLocation == '/onboarding';
        final isLogin = currentLocation == '/login';
        
        print('🔀 GoRouter redirect called:');
        print('  - Current location: $currentLocation');
        print('  - Onboarding completed: $hasCompleted');
        print('  - Is onboarding screen: $isOnboarding');
        print('  - Is login screen: $isLogin');
        
        // オンボーディング未完了の場合
        if (!hasCompleted) {
          // ログイン画面またはオンボーディング画面以外にアクセスした場合
          if (!isOnboarding && !isLogin) {
            print('  → Redirecting to /onboarding');
            return '/onboarding';
          }
        }
        
        // リダイレクト不要
        print('  → No redirect needed');
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/secret-key',
          builder: (context, state) => const SecretKeyManagementScreen(),
        ),
        GoRoute(
          path: '/settings/relays',
          builder: (context, state) => const RelayManagementScreen(),
        ),
        GoRoute(
          path: '/settings/app',
          builder: (context, state) => const AppSettingsDetailScreen(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // アプリのライフサイクル監視を終了
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // アプリがフォアグラウンドに復帰した時
    if (state == AppLifecycleState.resumed) {
      print('🔄 アプリがフォアグラウンドに復帰しました');
      _restoreNostrConnection();
    }
  }

  /// Nostr接続を復元する
  Future<void> _restoreNostrConnection() async {
    try {
      // 既に初期化済みかチェック
      final isInitialized = ref.read(nostrProvider.nostrInitializedProvider);
      if (isInitialized) {
        print('✅ Nostr接続は既に初期化済みです');
        return;
      }

      print('🔄 Nostr接続を復元しています...');

      // ローカルストレージでAmber使用フラグをチェック
      final isUsingAmber = localStorageService.isUsingAmber();
      print('🔍 Amber使用モード: $isUsingAmber');

      final nostrService = ref.read(nostrProvider.nostrServiceProvider);

      if (isUsingAmber) {
        // Amberモード: Rust側から公開鍵を取得
        final publicKey = await nostrService.getPublicKey();
        
        if (publicKey != null) {
          print('🔐 Amberモードで公開鍵を復元しました');
          
          // アプリ設定からリレーリストとプロキシURLを取得
          final appSettingsAsync = ref.read(appSettingsProvider);
          final relays = appSettingsAsync.value?.relays.isNotEmpty == true
              ? appSettingsAsync.value!.relays
              : null;
          final proxyUrl = appSettingsAsync.value?.torEnabled == true
              ? 'socks5://127.0.0.1:9050'
              : null;
          
          // Nostrクライアントを初期化（Amberモード）
          await nostrService.initializeNostrWithPubkey(
            publicKeyHex: publicKey,
            relays: relays,
            proxyUrl: proxyUrl,
          );
          
          print('✅ Amberモードでノstr接続を復元しました');
        } else {
          print('⚠️ 公開鍵が見つかりませんでした（Amberモード）');
        }
      } else {
        // 秘密鍵モード: 暗号化された秘密鍵が存在するかチェック
        final hasKey = await nostrService.hasEncryptedKey();
        
        if (hasKey) {
          print('🔐 秘密鍵モードで暗号化された秘密鍵が見つかりました');
          print('⚠️ パスワード入力が必要なため、自動復元をスキップします');
          // 秘密鍵モードはパスワードが必要なので自動復元しない
          // ユーザーが手動でログインする必要がある
        } else {
          print('ℹ️ 保存された認証情報がありません');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Nostr接続の復元に失敗しました: $e');
      print('スタックトレース: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      // エラーは無視（ユーザーは手動でログインできる）
    }
  }

  @override
  Widget build(BuildContext context) {
    // アプリ設定を監視してダークモード切り替え
    final appSettingsAsync = ref.watch(appSettingsProvider);
    
    return appSettingsAsync.when(
      data: (settings) {
        return MaterialApp.router(
          title: 'Meiso',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
        );
      },
      loading: () {
        // ローディング中はライトテーマで表示
        return MaterialApp.router(
          title: 'Meiso',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
        );
      },
      error: (error, stack) {
        // エラー時もライトテーマで表示
        return MaterialApp.router(
          title: 'Meiso',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
        );
      },
    );
  }
}
