import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../providers/bootstrap_sync_provider.dart';
import 'package:meiso/l10n/app_localizations.dart';

/// Phase 8.5.1: 同期中のローディングオーバーレイ
/// 
/// 初回同期時やデータが多い場合に、進捗パーセンテージを表示しながら
/// ユーザーに同期の進行状況を伝えます。
class SyncLoadingOverlay extends ConsumerWidget {
  const SyncLoadingOverlay({super.key});

  String _resolvePhaseText(
    AppLocalizations l10n,
    BootstrapSyncPhase phase,
  ) {
    switch (phase) {
      case BootstrapSyncPhase.none:
        return '';
      case BootstrapSyncPhase.continueWithLocalCache:
        return l10n.bootstrapPhaseContinueWithLocalCache;
      case BootstrapSyncPhase.fetchingAccountRelays:
        return l10n.bootstrapPhaseFetchingAccountRelays;
      case BootstrapSyncPhase.fetchingGlobalTodos:
        return l10n.bootstrapPhaseFetchingAllRelaysTodos;
      case BootstrapSyncPhase.fetchingGlobalGroupTodos:
        return l10n.bootstrapPhaseFetchingAllRelaysGroupTodos;
      case BootstrapSyncPhase.fetchingLocalTodos:
        return l10n.bootstrapPhaseFetchingLocalTodos;
      case BootstrapSyncPhase.fetchingLocalGroupTodos:
        return l10n.bootstrapPhaseFetchingLocalGroupTodos;
      case BootstrapSyncPhase.fetchingGroupInvitations:
        return l10n.bootstrapPhaseFetchingGroupInvitations;
      case BootstrapSyncPhase.syncCompleted:
        return l10n.bootstrapPhaseCompleted;
      case BootstrapSyncPhase.syncFailed:
        return l10n.bootstrapPhaseFailed;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(bootstrapSyncProvider);
    final l10n = AppLocalizations.of(context);
    
    if (!bootstrapState.isBlocking) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: Colors.transparent,
          ),
        ),
        // 背景ブラー + 半透明
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                  bootstrapState.errorMessage == null
                      ? l10n.syncing
                      : l10n.syncError,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (bootstrapState.errorMessage == null) ...[
                  const CircularProgressIndicator(),
                  Text(
                    _resolvePhaseText(l10n, bootstrapState.phase).isNotEmpty
                        ? _resolvePhaseText(l10n, bootstrapState.phase)
                        : l10n.syncLoadingData,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    bootstrapState.errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (bootstrapState.canFallbackToLocal)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            ref.read(bootstrapSyncProvider.notifier).continueWithLocalCache();
                          },
                          child: Text(l10n.bootstrapContinueWithLocalCacheButton),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(bootstrapSyncProvider.notifier).retryBootstrap();
                          },
                          child: Text(l10n.retryButton),
                        ),
                      ],
                    ),
                  if (!bootstrapState.canFallbackToLocal)
                    ElevatedButton(
                      onPressed: () {
                        ref.read(bootstrapSyncProvider.notifier).retryBootstrap();
                      },
                      child: Text(l10n.retryButton),
                    ),
                ],
                if (_resolvePhaseText(l10n, bootstrapState.phase).isNotEmpty &&
                    bootstrapState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _resolvePhaseText(l10n, bootstrapState.phase),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
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

