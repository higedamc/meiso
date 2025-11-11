import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';

/// エラーハンドリングユーティリティ
/// 
/// Phase 8.2で導入: 統一されたエラーハンドリングとリトライロジック
class ErrorHandler {
  /// ネットワークエラーかどうかを判定
  static bool isNetworkError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;
    
    // エラーメッセージから判定
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
           errorStr.contains('connection') ||
           errorStr.contains('timeout') ||
           errorStr.contains('socket') ||
           errorStr.contains('relay');
  }
  
  /// MLS固有エラーかどうかを判定
  static bool isMlsError(dynamic error) {
    if (error is! Exception) return false;
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('nomatchingkeypackage') ||
           errorStr.contains('pendingcommit') ||
           errorStr.contains('mls store not initialized') ||
           errorStr.contains('group') && errorStr.contains('not found');
  }
  
  /// Amber関連エラーかどうかを判定
  static bool isAmberError(dynamic error) {
    if (error is PlatformException) {
      return error.code.contains('AMBER') || 
             error.code.contains('NO_SIGNATURE');
    }
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('amber') || 
           errorStr.contains('signature cancelled');
  }
  
  /// ユーザー向けエラーメッセージに変換
  static String getUserFriendlyMessage(dynamic error) {
    // ネットワークエラー
    if (isNetworkError(error)) {
      if (error is TimeoutException) {
        return 'タイムアウト: ネットワーク接続を確認してください';
      }
      return '接続エラー: ネットワーク接続を確認してください';
    }
    
    // MLSエラー
    if (isMlsError(error)) {
      final errorStr = error.toString().toLowerCase();
      
      if (errorStr.contains('nomatchingkeypackage')) {
        return 'Key Packageが見つかりません。相手がまだKey Packageを公開していない可能性があります';
      }
      
      if (errorStr.contains('pendingcommit')) {
        return 'グループ状態を更新中です。しばらくお待ちください';
      }
      
      if (errorStr.contains('mls store not initialized')) {
        return 'MLS初期化中です。しばらくお待ちください';
      }
      
      if (errorStr.contains('group') && errorStr.contains('not found')) {
        return 'グループが見つかりません';
      }
      
      return 'グループ処理エラー: 再度お試しください';
    }
    
    // Amberエラー
    if (isAmberError(error)) {
      if (error is PlatformException && error.code == 'NO_SIGNATURE') {
        return '署名がキャンセルされました';
      }
      return 'Amber署名エラー: Amberアプリで承認してください';
    }
    
    // その他のエラー
    return 'エラーが発生しました: ${error.toString().substring(0, 50)}...';
  }
  
  /// リトライ可能なエラーかどうかを判定
  static bool isRetryable(dynamic error) {
    // ネットワークエラーはリトライ可能
    if (isNetworkError(error)) return true;
    
    // MLSのPendingCommitはリトライ可能
    if (isMlsError(error)) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('pendingcommit')) return true;
      if (errorStr.contains('mls store not initialized')) return true;
    }
    
    // Amberエラーはリトライ不可（ユーザー操作必要）
    if (isAmberError(error)) return false;
    
    return false;
  }
  
  /// 指数バックオフでリトライ実行
  /// 
  /// [operation]: リトライする非同期処理
  /// [maxAttempts]: 最大試行回数（デフォルト: 3）
  /// [initialDelay]: 初回遅延時間（デフォルト: 1秒）
  /// [maxDelay]: 最大遅延時間（デフォルト: 10秒）
  /// [retryIf]: リトライ条件（デフォルト: isRetryable）
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
    bool Function(dynamic error)? retryIf,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (true) {
      attempt++;
      
      try {
        AppLogger.debug('🔄 [Retry] Attempt $attempt/$maxAttempts');
        return await operation();
      } catch (e, stackTrace) {
        // 最後の試行でエラーが発生した場合は再スロー
        if (attempt >= maxAttempts) {
          AppLogger.error(
            '❌ [Retry] Failed after $maxAttempts attempts',
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }
        
        // リトライ条件チェック
        final shouldRetry = retryIf != null ? retryIf(e) : isRetryable(e);
        
        if (!shouldRetry) {
          AppLogger.warning(
          '⏭️  [Retry] Error is not retryable');
          rethrow;
        }
        
        // エラーログ
        AppLogger.warning(
          '⚠️ [Retry] Attempt $attempt failed, retrying in ${delay.inSeconds}s',
          error: e,
        );
        
        // 指数バックオフ
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            initialDelay.inMilliseconds,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }
  
  /// タイムアウト付きで処理を実行
  /// 
  /// [operation]: 実行する非同期処理
  /// [timeout]: タイムアウト時間
  /// [onTimeout]: タイムアウト時のフォールバック（オプション）
  static Future<T> withTimeout<T>({
    required Future<T> Function() operation,
    required Duration timeout,
    T Function()? onTimeout,
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: onTimeout,
      );
    } on TimeoutException {
      AppLogger.warning('⏱️ [Timeout] Operation timed out after ${timeout.inSeconds}s');
      
      if (onTimeout != null) {
        AppLogger.info('🔄 [Timeout] Using fallback value');
        return onTimeout();
      }
      
      rethrow;
    }
  }
  
  /// オフライン対応: ローカルファーストパターン
  /// 
  /// [localOperation]: ローカル処理（必ず実行）
  /// [remoteOperation]: リモート処理（ネットワーク経由）
  /// [onRemoteError]: リモート失敗時のコールバック（オプション）
  static Future<T> localFirst<T>({
    required Future<T> Function() localOperation,
    required Future<void> Function() remoteOperation,
    void Function(dynamic error)? onRemoteError,
  }) async {
    // 1. ローカル処理を先に実行（即座にUI更新）
    AppLogger.debug('💾 [LocalFirst] Executing local operation');
    final result = await localOperation();
    
    // 2. バックグラウンドでリモート同期
    remoteOperation().then(
      (_) {
        AppLogger.info('☁️ [LocalFirst] Remote sync completed');
      },
    ).catchError((error, stackTrace) {
      AppLogger.warning(
        '⚠️ [LocalFirst] Remote sync failed (local data preserved)',
        error: error,
      );
      
      if (onRemoteError != null) {
        onRemoteError(error);
      }
    });
    
    return result;
  }
  
  /// ネットワーク状態を確認してから処理を実行
  /// 
  /// オフラインの場合は即座にローカル処理のみ実行
  static Future<T> onlineFirst<T>({
    required Future<T> Function() onlineOperation,
    required Future<T> Function() offlineOperation,
  }) async {
    try {
      // オンライン処理を試行
      AppLogger.debug('🌐 [OnlineFirst] Trying online operation');
      return await withTimeout(
        operation: onlineOperation,
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      // ネットワークエラーの場合はオフライン処理
      if (isNetworkError(e)) {
        AppLogger.info('📴 [OnlineFirst] Network error, falling back to offline');
        return await offlineOperation();
      }
      
      // その他のエラーは再スロー
      rethrow;
    }
  }
}

