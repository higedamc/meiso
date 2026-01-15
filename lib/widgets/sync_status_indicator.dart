import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/nostr_provider.dart';

/// 接続方法インジケーター（シンプルな色付きドット）
/// Android の権限使用中インジケーターと同様のデザイン
/// 緑 = Clearnet（通常接続）、青 = Tor（プロキシ経由）
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final appSettingsAsync = ref.watch(appSettingsProvider);

    // Nostr未初期化の場合は非表示
    if (!isNostrInitialized) {
      return const SizedBox.shrink();
    }

    return appSettingsAsync.when(
      data: (settings) {
        final isTorEnabled = settings.torMode != TorMode.disabled;
        return _buildDotIndicator(isTorEnabled);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// シンプルなドットインジケーター
  Widget _buildDotIndicator(bool isTorEnabled) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isTorEnabled 
            ? Colors.blue.shade600   // Tor: 青色
            : Colors.green.shade600, // Clearnet: 緑色
      ),
    );
  }
}


