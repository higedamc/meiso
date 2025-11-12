import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../providers/sync_status_provider.dart';

/// Phase 8.5.1: 同期中のローディングオーバーレイ
/// 
/// 初回同期時やデータが多い場合に、進捗パーセンテージを表示しながら
/// ユーザーに同期の進行状況を伝えます。
class SyncLoadingOverlay extends ConsumerWidget {
  const SyncLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    
    // 同期中でない場合は表示しない
    if (syncStatus.state != SyncState.syncing) {
      return const SizedBox.shrink();
    }
    
    // 進捗が0%の場合のみ表示（初回同期時）
    // または totalSteps が設定されている場合（Phase 8.5.1の進捗追跡が有効）
    if (syncStatus.totalSteps == 0 && syncStatus.percentage == 0) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        // 背景ブラー + 半透明
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              color: isDark 
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.7),
            ),
          ),
        ),
        
        // 中央のローディングカード
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // タイトル
                Text(
                  '同期中',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 進捗パーセンテージ（大きく表示）
                Text(
                  '${syncStatus.percentage}%',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 進捗バー
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: syncStatus.percentage / 100.0,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 現在のフェーズ
                if (syncStatus.currentPhase != null) ...[
                  Text(
                    syncStatus.currentPhase!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                // メッセージがある場合は表示
                if (syncStatus.message != null && 
                    syncStatus.message!.isNotEmpty &&
                    syncStatus.message != syncStatus.currentPhase) ...[
                  const SizedBox(height: 8),
                  Text(
                    syncStatus.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                // ステップ表示（例: "2 / 3"）
                if (syncStatus.totalSteps > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ステップ ${syncStatus.completedSteps} / ${syncStatus.totalSteps}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

