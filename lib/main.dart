import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_theme.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/onboarding/login_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'bridge_generated.dart/frb_generated.dart';
import 'services/local_storage_service.dart';

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

class _MeisoAppState extends ConsumerState<MeisoApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Meiso',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
