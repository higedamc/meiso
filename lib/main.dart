import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'app_theme.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/onboarding/login_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/settings/secret_key_management_screen.dart';
import 'presentation/settings/relay_management_screen.dart';
import 'presentation/settings/app_settings_detail_screen.dart';
import 'presentation/settings/cryptography_detail_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'bridge_generated.dart/api.dart' as rust_api;
import 'bridge_generated.dart/frb_generated.dart';
import 'services/local_storage_service.dart';
import 'services/logger_service.dart';
import 'models/app_settings.dart';
import 'providers/app_settings_provider.dart';
import 'providers/bootstrap_sync_provider.dart';
import 'providers/app_lifecycle_provider.dart';
import 'providers/relay_connectivity_monitor_provider.dart';
import 'providers/nostr_provider.dart' as nostrProvider;
import 'providers/locale_provider.dart';
import 'widgets/sync_loading_overlay.dart'; // Phase 8.5.1
// Phase D.5: MLS UseCase統合
import 'features/mls/application/providers/usecase_providers.dart';
import 'features/mls/application/usecases/auto_publish_key_package_usecase.dart';
import 'features/mls/domain/value_objects/key_package_publish_policy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // リリースビルドでもウィジェットエラーを視覚的に表示
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Widget error:\n${details.exception}\n\n${details.stack}',
            style: const TextStyle(fontSize: 11, color: Colors.red),
          ),
        ),
      ),
    );
  };

  // 英語ロケール初期化
  await initializeDateFormatting('en_US');

  // ローカルストレージの初期化
  try {
    await localStorageService.initialize();
    AppLogger.info('ローカルストレージ初期化成功', tag: 'INIT');
  } catch (e) {
    AppLogger.error('ローカルストレージ初期化エラー', error: e, tag: 'INIT');
  }

  // Rustブリッジの初期化
  try {
    await RustLib.init();
    AppLogger.info('Rust初期化成功', tag: 'INIT');

    // 永続イベントキャッシュ (nostr-lmdb) の初期化。
    // Nostr クライアント生成より前に一度だけ呼ぶ。
    // 失敗しても in-memory DB で動作するため致命的エラーにはしない。
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      await rust_api.initNostrDb(dbDir: appDocDir.path);
      AppLogger.info('Nostr DB (lmdb) 初期化成功', tag: 'INIT');
    } catch (e) {
      AppLogger.error('Nostr DB 初期化エラー (in-memory で継続)', error: e, tag: 'INIT');
    }

    // Rust 側の同期メタデータログ（negentropy 等）を Talker に転送する。
    // メタデータ（リレー数・件数）のみでイベント内容や鍵は含まれない。
    try {
      rust_api.initSyncLogStream().listen(
        (msg) => AppLogger.info(msg, tag: 'RUST_SYNC'),
        onError: (Object e) =>
            AppLogger.warning('Rust sync log stream error: $e', tag: 'INIT'),
      );
    } catch (e) {
      AppLogger.warning('Rust sync log stream 初期化失敗: $e', tag: 'INIT');
    }
  } catch (e, stackTrace) {
    AppLogger.error(
      'Rust初期化エラー',
      error: e,
      stackTrace: stackTrace,
      tag: 'INIT',
    );
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Rust init failed:\n$e\n\n$stackTrace',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
    return;
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

    // AppLifecycleProviderを初期化（アプリのライフサイクル監視を開始）
    // これによりフォアグラウンド復帰時の自動再接続・同期が有効になります
    ref.read(appLifecycleProvider);
    ref.read(bootstrapSyncProvider.notifier);
    // リレー接続性の定期監視を起動（実 WebSocket 状態を UI へ反映）
    ref.read(relayConnectivityMonitorProvider);

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

        AppLogger.debug('GoRouter redirect called:', tag: 'ROUTER');
        AppLogger.debug(
          '  - Current location: $currentLocation',
          tag: 'ROUTER',
        );
        AppLogger.debug(
          '  - Onboarding completed: $hasCompleted',
          tag: 'ROUTER',
        );
        AppLogger.debug(
          '  - Is onboarding screen: $isOnboarding',
          tag: 'ROUTER',
        );
        AppLogger.debug('  - Is login screen: $isLogin', tag: 'ROUTER');

        // オンボーディング未完了の場合
        if (!hasCompleted) {
          // ログイン画面またはオンボーディング画面以外にアクセスした場合
          if (!isOnboarding && !isLogin) {
            AppLogger.debug('  → Redirecting to /onboarding', tag: 'ROUTER');
            return '/onboarding';
          }
        }

        // リダイレクト不要
        AppLogger.debug('  → No redirect needed', tag: 'ROUTER');
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
        GoRoute(
          path: '/settings/secret-key/cryptography',
          builder: (context, state) => const CryptographyDetailScreen(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Nostr接続を復元する
  Future<void> _restoreNostrConnection() async {
    try {
      // 既に初期化済みかチェック
      final isInitialized = ref.read(nostrProvider.nostrInitializedProvider);
      if (isInitialized) {
        AppLogger.info('Nostr接続は既に初期化済みです', tag: 'NOSTR');
        return;
      }

      AppLogger.info('Nostr接続を復元しています...', tag: 'NOSTR');

      // ローカルストレージでAmber使用フラグをチェック
      final isUsingAmber = localStorageService.isUsingAmber();
      AppLogger.debug('Amber使用モード: $isUsingAmber', tag: 'NOSTR');

      final nostrService = ref.read(nostrProvider.nostrServiceProvider);

      if (isUsingAmber) {
        // Amberモード: Rust側から公開鍵を取得
        AppLogger.debug('Rust側から公開鍵を読み込み中...', tag: 'AMBER');
        final publicKey = await nostrService.getPublicKey();
        AppLogger.debug(
          '公開鍵の取得結果: ${publicKey != null ? "取得成功 (${publicKey.substring(0, 16)}...)" : "null"}',
          tag: 'AMBER',
        );

        if (publicKey != null) {
          AppLogger.info(
            'Amberモードで公開鍵を復元しました: ${publicKey.substring(0, 16)}...',
            tag: 'AMBER',
          );

          // アプリ設定からリレーリストとプロキシURLを取得
          final appSettingsAsync = ref.read(appSettingsProvider);
          final relays = appSettingsAsync.value?.relays.isNotEmpty == true
              ? appSettingsAsync.value!.relays
              : null;
          // TorMode に応じてプロキシURLを設定
          final torMode = appSettingsAsync.value?.torMode ?? TorMode.disabled;
          final proxyUrl = torMode == TorMode.orbot
              ? appSettingsAsync.value?.proxyUrl ?? 'socks5://127.0.0.1:9050'
              : null;

          AppLogger.debug('リレー設定: ${relays ?? "デフォルトリレー"}', tag: 'NOSTR');
          AppLogger.debug('プロキシ: ${proxyUrl ?? "なし"}', tag: 'NOSTR');

          // Nostrクライアントを初期化（Amberモード）
          AppLogger.debug('Nostrクライアントを初期化中...', tag: 'NOSTR');
          await nostrService.initializeNostrWithPubkey(
            publicKeyHex: publicKey,
            relays: relays,
            torMode: torMode,
            proxyUrl: proxyUrl,
          );

          // 復元後のProvider状態を確認
          final restoredHex = ref.read(nostrProvider.publicKeyProvider);
          final restoredNpub = ref.read(nostrProvider.nostrPublicKeyProvider);
          AppLogger.info('Amberモードでノstr接続を復元しました', tag: 'NOSTR');
          AppLogger.debug(
            '復元後のhex公開鍵: ${restoredHex != null ? "${restoredHex.substring(0, 16)}..." : "null"}',
            tag: 'NOSTR',
          );
          AppLogger.debug(
            '復元後のnpub公開鍵: ${restoredNpub != null ? "${restoredNpub.substring(0, 16)}..." : "null"}',
            tag: 'NOSTR',
          );

          // 起動時ブートストラップ（初回はブロック、既存データありは非ブロック）
          Future.microtask(() async {
            await ref
                .read(bootstrapSyncProvider.notifier)
                .runBootstrapIfNeeded();
          });

          // Phase 8.1 + Phase D.5: Key Package自動公開（UseCase統合）
          try {
            AppLogger.info('[復元] Key Package自動公開チェック...', tag: 'MLS');
            final autoPublishUseCase = ref.read(
              autoPublishKeyPackageUseCaseProvider,
            );
            final result = await autoPublishUseCase(
              AutoPublishKeyPackageParams(
                publicKey: publicKey,
                trigger: KeyPackagePublishTrigger.appStart,
              ),
            );

            result.fold(
              (failure) {
                AppLogger.warning(
                  '[復元] Key Package自動公開エラー: ${failure.message}',
                  tag: 'MLS',
                );
              },
              (eventId) {
                if (eventId != null) {
                  AppLogger.info(
                    '[復元] Key Package自動公開成功: ${eventId.substring(0, 16)}...',
                    tag: 'MLS',
                  );
                } else {
                  AppLogger.debug('[復元] Key Package は最新（公開スキップ）', tag: 'MLS');
                }
              },
            );
          } catch (e) {
            AppLogger.warning('[復元] Key Package自動公開エラー', error: e, tag: 'MLS');
            // エラーは無視（必須ではない）
          }
        } else {
          AppLogger.warning('公開鍵が見つかりませんでした（Amberモード）', tag: 'AMBER');
          AppLogger.debug(
            '公開鍵ファイルが存在するか: ${await nostrService.hasPublicKey()}',
            tag: 'AMBER',
          );
        }
      } else {
        // 秘密鍵モード: 暗号化された秘密鍵が存在するかチェック
        final hasKey = await nostrService.hasEncryptedKey();

        if (hasKey) {
          AppLogger.info('秘密鍵モードで暗号化された秘密鍵が見つかりました', tag: 'NOSTR');
          AppLogger.debug('パスワード入力が必要なため、自動復元をスキップします', tag: 'NOSTR');
          // 秘密鍵モードはパスワードが必要なので自動復元しない
          // ユーザーが手動でログインする必要がある
        } else {
          AppLogger.debug('保存された認証情報がありません', tag: 'NOSTR');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Nostr接続の復元に失敗しました',
        error: e,
        stackTrace: stackTrace,
        tag: 'NOSTR',
      );
      // エラーは無視（ユーザーは手動でログインできる）
    }
  }

  @override
  Widget build(BuildContext context) {
    // アプリ設定を監視してダークモード切り替え
    final appSettingsAsync = ref.watch(appSettingsProvider);
    // ロケール設定を監視
    final locale = ref.watch(localeProvider);

    return appSettingsAsync.when(
      data: (settings) {
        return MaterialApp.router(
          title: 'Meiso',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          // 多言語対応
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ja'), // Japanese
            Locale('es'), // Spanish
          ],
          locale: locale,
          // Android 13+の「App languages」設定を優先的に反映
          localeListResolutionCallback: (systemLocales, supportedLocales) {
            // ユーザーが手動で言語を設定している場合はそれを優先
            if (locale != null) {
              return locale;
            }

            // システムのロケールリスト（App languages設定を含む）から
            // サポートしている言語を探す
            if (systemLocales != null) {
              for (final systemLocale in systemLocales) {
                for (final supportedLocale in supportedLocales) {
                  if (systemLocale.languageCode ==
                      supportedLocale.languageCode) {
                    return supportedLocale;
                  }
                }
              }
            }

            // マッチする言語がない場合は英語をデフォルトとする
            return const Locale('en');
          },
          // Phase 8.5.1: 同期中のローディングオーバーレイをbuilderで統合
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const SyncLoadingOverlay(),
              ],
            );
          },
        );
      },
      loading: () {
        // ローディング中はライトテーマで表示
        return MaterialApp.router(
          title: 'Meiso',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          // 多言語対応
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ja'), // Japanese
            Locale('es'), // Spanish
          ],
          locale: locale,
          localeListResolutionCallback: (systemLocales, supportedLocales) {
            if (locale != null) {
              return locale;
            }

            if (systemLocales != null) {
              for (final systemLocale in systemLocales) {
                for (final supportedLocale in supportedLocales) {
                  if (systemLocale.languageCode ==
                      supportedLocale.languageCode) {
                    return supportedLocale;
                  }
                }
              }
            }

            return const Locale('en');
          },
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const SyncLoadingOverlay(),
              ],
            );
          },
        );
      },
      error: (error, stack) {
        // エラー時もライトテーマで表示
        return MaterialApp.router(
          title: 'Meiso',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          // 多言語対応
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ja'), // Japanese
            Locale('es'), // Spanish
          ],
          locale: locale,
          localeListResolutionCallback: (systemLocales, supportedLocales) {
            if (locale != null) {
              return locale;
            }

            if (systemLocales != null) {
              for (final systemLocale in systemLocales) {
                for (final supportedLocale in supportedLocales) {
                  if (systemLocale.languageCode ==
                      supportedLocale.languageCode) {
                    return supportedLocale;
                  }
                }
              }
            }

            return const Locale('en');
          },
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const SyncLoadingOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}
