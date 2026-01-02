import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../providers/sync_status_provider.dart';

/// 同期ステータスインジケーター
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator> {
  Timer? _hideTimer;
  bool _isVisible = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onSyncStatusChanged(SyncStatus status) {
    // 同期完了後、3秒で非表示にする
    if (status.state == SyncState.success) {
      setState(() => _isVisible = true);
      
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    } else if (status.state == SyncState.syncing) {
      // 同期中は表示
      setState(() => _isVisible = true);
      _hideTimer?.cancel();
    } else if (status.state == SyncState.error) {
      // エラー時は表示し、5秒後に自動的に非表示にする
      setState(() => _isVisible = true);
      
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    } else if (status.state == SyncState.idle) {
      // アイドル時は非表示
      setState(() => _isVisible = false);
      _hideTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);

    // 同期ステータスが変わったら処理
    ref.listen<SyncStatus>(syncStatusProvider, (previous, next) {
      _onSyncStatusChanged(next);
    });

    if (syncStatus.state == SyncState.notInitialized) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _isVisible
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getBackgroundColor(syncStatus.state),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(syncStatus.state),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getStatusText(context, syncStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getTextColor(syncStatus.state),
                        ),
                      ),
                      if (syncStatus.lastSyncTime != null)
                        Text(
                          _formatSyncTime(context, syncStatus.lastSyncTime!),
                          style: TextStyle(
                            fontSize: 9,
                            color: _getTextColor(syncStatus.state).withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// ステータスアイコン
  Widget _buildIcon(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getTextColor(state),
            ),
          ),
        );
      case SyncState.success:
        return Icon(
          Icons.cloud_done,
          size: 14,
          color: _getTextColor(state),
        );
      case SyncState.error:
        return Icon(
          Icons.cloud_off,
          size: 14,
          color: _getTextColor(state),
        );
      case SyncState.idle:
        return Icon(
          Icons.cloud_queue,
          size: 14,
          color: _getTextColor(state),
        );
      case SyncState.notInitialized:
        return const SizedBox.shrink();
    }
  }

  /// ステータステキスト
  String _getStatusText(BuildContext context, SyncStatus status) {
    final l10n = AppLocalizations.of(context);
    
    // カスタムメッセージがあればそれを優先
    if (status.message != null && status.message!.isNotEmpty) {
      final msg = status.message!;
      const prefix = '__l10n__:';
      if (msg.startsWith(prefix)) {
        final key = msg.substring(prefix.length);
        switch (key) {
          case 'syncReconnectingRelays':
            return l10n.syncReconnectingRelays;
          case 'syncPhaseDelta':
            return l10n.syncPhaseDelta;
          case 'syncPhaseAppSettings':
            return l10n.syncPhaseAppSettings;
          case 'syncPhaseCustomLists':
            return l10n.syncPhaseCustomLists;
          case 'syncPhaseTodos':
            return l10n.syncPhaseTodos;
          case 'syncPhaseMls':
            return l10n.syncPhaseMls;
          case 'syncCompleted':
            return l10n.syncCompleted;
          default:
            // 未定義キーは表示しない（英日混在の温床を避ける）
            break;
        }
      }
      // 生文字列は英日混在の原因になるので、クラウドインジケータでは使わない
    }
    
    switch (status.state) {
      case SyncState.syncing:
        if (status.pendingItems > 0) {
          return l10n.syncingWithCount(status.pendingItems);
        }
        return l10n.syncing;
      case SyncState.success:
        return l10n.syncCompleted;
      case SyncState.error:
        // リトライ回数がある場合はそれを表示
        if (status.retryCount > 0) {
          return l10n.errorRetry(status.retryCount);
        }
        // エラーメッセージが __l10n__: プレフィックス付きの場合は解決
        final errorMsg = status.errorMessage;
        if (errorMsg != null && errorMsg.startsWith('__l10n__:')) {
          final key = errorMsg.substring('__l10n__:'.length);
          switch (key) {
            case 'timeout':
              return l10n.timeout;
            case 'connectionError':
              return l10n.connectionError;
            case 'syncError':
              return l10n.syncError;
            default:
              return l10n.syncError;
          }
        }
        // デフォルトは一般的な同期エラー
        return l10n.syncError;
      case SyncState.idle:
        return l10n.waiting;
      case SyncState.notInitialized:
        return '';
    }
  }

  /// 最終同期時刻をフォーマット
  String _formatSyncTime(BuildContext context, DateTime time) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else {
      return DateFormat('MM/dd HH:mm').format(time);
    }
  }

  /// 背景色
  Color _getBackgroundColor(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return Colors.blue.shade50;
      case SyncState.success:
        return Colors.green.shade50;
      case SyncState.error:
        return Colors.red.shade50;
      case SyncState.idle:
        return Colors.grey.shade100;
      case SyncState.notInitialized:
        return Colors.transparent;
    }
  }

  /// テキスト色
  Color _getTextColor(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return Colors.blue.shade700;
      case SyncState.success:
        return Colors.green.shade700;
      case SyncState.error:
        return Colors.red.shade700;
      case SyncState.idle:
        return Colors.grey.shade700;
      case SyncState.notInitialized:
        return Colors.transparent;
    }
  }
}


