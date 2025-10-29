import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_theme.dart';
import 'presentation/home/home_screen.dart';
import 'bridge_generated.dart' as bridge;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 英語ロケール初期化
  await initializeDateFormatting('en_US');
  
  // Rustブリッジの初期化
  await bridge.init();
  
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
