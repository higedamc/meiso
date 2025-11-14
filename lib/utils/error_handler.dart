import 'dart:async';
import '../services/logger_service.dart';

/// Phase 8.2: エラーハンドリングユーティリティ

/// エラーカテゴリ
enum ErrorCategory {
  network,      // ネットワークエラー（オフライン、タイムアウト等）
  mls,          // MLS固有エラー
  nostr,        // Nostrプロトコルエラー
  storage,      // ローカルストレージエラー
  auth,         // 認証エラー（Amber等）
  unknown,      // 不明なエラー
}

/// エラー情報
class AppError {
  final ErrorCategory category;
  final String technicalMessage;  // 開発者向け詳細メッセージ
  final String userMessage;       // ユーザー向けわかりやすいメッセージ
  final bool isRetryable;         // リトライ可能か
  final Object? originalError;    // 元のエラーオブジェクト

  AppError({
    required this.category,
    required this.technicalMessage,
    required this.userMessage,
    this.isRetryable = false,
    this.originalError,
  });

  @override
  String toString() {
    return 'AppError(category: $category, technical: $technicalMessage, user: $userMessage, retryable: $isRetryable)';
  }
}

/// エラーハンドラー
class ErrorHandler {
  /// エラーを分類してAppErrorに変換
  static AppError classify(Object error, {StackTrace? stackTrace}) {
    final errorStr = error.toString().toLowerCase();

    // ネットワークエラー
    if (_isNetworkError(errorStr)) {
      return AppError(
        category: ErrorCategory.network,
        technicalMessage: error.toString(),
        userMessage: 'ネットワーク接続を確認してください',
        isRetryable: true,
        originalError: error,
      );
    }

    // MLS固有エラー
    if (_isMlsError(errorStr)) {
      return _classifyMlsError(error, errorStr);
    }

    // Nostrエラー
    if (_isNostrError(errorStr)) {
      return AppError(
        category: ErrorCategory.nostr,
        technicalMessage: error.toString(),
        userMessage: 'リレーとの通信エラーが発生しました',
        isRetryable: true,
        originalError: error,
      );
    }

    // ストレージエラー
    if (_isStorageError(errorStr)) {
      return AppError(
        category: ErrorCategory.storage,
        technicalMessage: error.toString(),
        userMessage: 'データの保存に失敗しました',
        isRetryable: false,
        originalError: error,
      );
    }

    // Amber認証エラー
    if (_isAmberError(errorStr)) {
      return AppError(
        category: ErrorCategory.auth,
        technicalMessage: error.toString(),
        userMessage: 'Amberでの署名がキャンセルされました',
        isRetryable: true,
        originalError: error,
      );
    }

    // 不明なエラー
    return AppError(
      category: ErrorCategory.unknown,
      technicalMessage: error.toString(),
      userMessage: '予期しないエラーが発生しました',
      isRetryable: false,
      originalError: error,
    );
  }

  /// ネットワークエラーの判定
  static bool _isNetworkError(String errorStr) {
    return errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('unreachable') ||
        errorStr.contains('offline') ||
        errorStr.contains('failed to connect');
  }

  /// MLSエラーの判定
  static bool _isMlsError(String errorStr) {
    return errorStr.contains('mls') ||
        errorStr.contains('key package') ||
        errorStr.contains('nomatchingkeypackage') ||
        errorStr.contains('pendingcommit') ||
        errorStr.contains('welcome') ||
        errorStr.contains('group state');
  }

  /// MLSエラーの詳細分類
  static AppError _classifyMlsError(Object error, String errorStr) {
    // NoMatchingKeyPackage: Key Packageが見つからない
    if (errorStr.contains('nomatchingkeypackage') || 
        errorStr.contains('key package not found')) {
      return AppError(
        category: ErrorCategory.mls,
        technicalMessage: error.toString(),
        userMessage: 'メンバーのKey Packageが見つかりません。相手にアプリを起動してもらってください',
        isRetryable: true,
        originalError: error,
      );
    }

    // PendingCommit: コミット待ち状態
    if (errorStr.contains('pendingcommit')) {
      return AppError(
        category: ErrorCategory.mls,
        technicalMessage: error.toString(),
        userMessage: '処理中です。しばらくお待ちください',
        isRetryable: true,
        originalError: error,
      );
    }

    // Welcome Message関連
    if (errorStr.contains('welcome')) {
      return AppError(
        category: ErrorCategory.mls,
        technicalMessage: error.toString(),
        userMessage: 'グループ招待の処理に失敗しました',
        isRetryable: true,
        originalError: error,
      );
    }

    // その他のMLSエラー
    return AppError(
      category: ErrorCategory.mls,
      technicalMessage: error.toString(),
      userMessage: 'グループ暗号化エラーが発生しました',
      isRetryable: false,
      originalError: error,
    );
  }

  /// Nostrエラーの判定
  static bool _isNostrError(String errorStr) {
    return errorStr.contains('nostr') ||
        errorStr.contains('relay') ||
        errorStr.contains('event') ||
        errorStr.contains('subscription');
  }

  /// ストレージエラーの判定
  static bool _isStorageError(String errorStr) {
    return errorStr.contains('storage') ||
        errorStr.contains('hive') ||
        errorStr.contains('file') ||
        errorStr.contains('permission denied');
  }

  /// Amberエラーの判定
  static bool _isAmberError(String errorStr) {
    return errorStr.contains('amber') ||
        errorStr.contains('signature') ||
        errorStr.contains('cancelled') ||
        errorStr.contains('user rejected');
  }

  /// Phase 8.2.1: リトライロジック（指数バックオフ）
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      attempt++;
      try {
        AppLogger.debug('🔄 [$operationName] Attempt $attempt/$maxAttempts');
        return await operation();
      } catch (e, stackTrace) {
        final appError = classify(e, stackTrace: stackTrace);
        
        // リトライ不可能なエラーの場合は即座にスロー
        if (!appError.isRetryable) {
          AppLogger.error(
            '❌ [$operationName] Non-retryable error',
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }

        // 最大試行回数に達した場合はスロー
        if (attempt >= maxAttempts) {
          AppLogger.error(
            '❌ [$operationName] Max attempts ($maxAttempts) reached',
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }

        // リトライ待機
        AppLogger.warning(
          '⚠️ [$operationName] Attempt $attempt failed, retrying in ${currentDelay.inSeconds}s...',
          error: e,
        );
        await Future.delayed(currentDelay);

        // 次回の待機時間を計算（指数バックオフ）
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
  }

  /// Phase 8.2.3: タイムアウト付き実行
  static Future<T> withTimeout<T>({
    required Future<T> Function() operation,
    required String operationName,
    Duration timeout = const Duration(seconds: 10),
    T? defaultValue,
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          AppLogger.warning('⏱️ [$operationName] Operation timed out after ${timeout.inSeconds}s');
          if (defaultValue != null) {
            return defaultValue!;
          }
          throw TimeoutException('$operationName timed out after ${timeout.inSeconds}s');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [$operationName] Operation failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Phase 8.2.3: オフライン状態の判定
  static bool isOfflineError(Object error) {
    final appError = classify(error);
    return appError.category == ErrorCategory.network;
  }

  /// エラーログを記録
  static void logError(
    String message,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final appError = classify(error, stackTrace: stackTrace);
    
    AppLogger.error(
      '$message\n'
      'Category: ${appError.category}\n'
      'User Message: ${appError.userMessage}\n'
      'Technical: ${appError.technicalMessage}\n'
      'Retryable: ${appError.isRetryable}',
      error: error,
      stackTrace: stackTrace,
    );

    if (context != null && context.isNotEmpty) {
      AppLogger.debug('Context: $context');
    }
  }
}
