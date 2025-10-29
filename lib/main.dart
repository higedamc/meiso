import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_theme.dart';
import 'presentation/home/home_screen.dart';
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

class MeisoApp extends StatelessWidget {
  const MeisoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meiso',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
