import 'package:talker_flutter/talker_flutter.dart';
import 'package:flutter/foundation.dart';

/// グローバルTalkerインスタンス
/// デバッグモード時のみログを有効化
final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: kDebugMode,
    useConsoleLogs: kDebugMode,
  ),
  logger: TalkerLogger(
    settings: TalkerLoggerSettings(
      enableColors: kDebugMode,
    ),
  ),
);

/// アプリ全体で使用するロガー
/// セキュリティを考慮し、秘密鍵などの機密情報を自動マスキング
class AppLogger {
  /// 秘密鍵などを含む可能性のある文字列をマスク
  static String _sanitize(String message) {
    if (kReleaseMode) return '[REDACTED]';

    // nsecやhexキーっぽい文字列をマスク
    return message
        .replaceAllMapped(RegExp(r'nsec1[a-z0-9]{58}'), (_) => 'nsec1***')
        .replaceAllMapped(
            RegExp(r'[0-9a-f]{64}'), (_) => '***hex-key-redacted***');
  }

  /// デバッグレベルのログ（開発時の詳細情報）
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      talker.debug(tag != null ? '[$tag] $sanitized' : sanitized);
    }
  }

  /// 情報レベルのログ（重要な処理の完了など）
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      talker.info(tag != null ? '[$tag] $sanitized' : sanitized);
    }
  }

  /// 警告レベルのログ（問題の可能性があるが継続可能）
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      talker.warning(
        tag != null ? '[$tag] $sanitized' : sanitized,
        error,
        stackTrace,
      );
    }
  }

  /// エラーレベルのログ（エラーが発生したが処理は継続）
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      talker.error(
        tag != null ? '[$tag] $sanitized' : sanitized,
        error,
        stackTrace,
      );
    }
  }

  /// 重大なエラーレベルのログ（アプリの動作に影響）
  static void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      talker.critical(
        tag != null ? '[$tag] $sanitized' : sanitized,
        error,
        stackTrace,
      );
    }
  }
}

