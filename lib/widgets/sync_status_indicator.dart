import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    } else if (status.state == SyncState.syncing || 
               status.state == SyncState.error) {
      // 同期中またはエラー時は表示
      setState(() => _isVisible = true);
      _hideTimer?.cancel();
    } else if (status.state == SyncState.idle) {
      // アイドル時は非表示
      setState(() => _isVisible = false);
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
                        _getStatusText(syncStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getTextColor(syncStatus.state),
                        ),
                      ),
                      if (syncStatus.lastSyncTime != null)
                        Text(
                          _formatSyncTime(syncStatus.lastSyncTime!),
                          style: TextStyle(
                            fontSize: 9,
                            color: _getTextColor(syncStatus.state).withOpacity(0.7),
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
  String _getStatusText(SyncStatus status) {
    // カスタムメッセージがあればそれを優先
    if (status.message != null && status.message!.isNotEmpty) {
      return status.message!;
    }
    
    switch (status.state) {
      case SyncState.syncing:
        if (status.pendingItems > 0) {
          return '同期中 (${status.pendingItems})';
        }
        return '同期中';
      case SyncState.success:
        return '同期完了';
      case SyncState.error:
        if (status.retryCount > 0) {
          return 'エラー (リトライ${status.retryCount}回)';
        }
        return '同期エラー';
      case SyncState.idle:
        return '待機中';
      case SyncState.notInitialized:
        return '';
    }
  }

  /// 最終同期時刻をフォーマット
  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
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

