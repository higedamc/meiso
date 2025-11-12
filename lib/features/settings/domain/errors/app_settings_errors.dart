import '../../../../core/common/failure.dart';

/// アプリ設定関連のエラー種別
enum AppSettingsError {
  /// 設定が見つからない
  notFound,
  
  /// ストレージエラー
  storageError,
  
  /// 同期エラー
  syncError,
  
  /// Nostr接続エラー
  nostrConnectionError,
  
  /// Amber連携エラー
  amberError,
  
  /// 無効な値
  invalidValue,
  
  /// 予期しないエラー
  unexpected,
}

/// AppSettingsに関するFailure
class AppSettingsFailure extends Failure {
  const AppSettingsFailure(this.error, String message) : super(message);
  
  final AppSettingsError error;
  
  @override
  String toString() => 'AppSettingsFailure(error: $error, message: $message)';
}

/// AppSettingsErrorの拡張メソッド
extension AppSettingsErrorExtension on AppSettingsError {
  /// エラーメッセージを取得
  String get message {
    switch (this) {
      case AppSettingsError.notFound:
        return '設定が見つかりませんでした';
      case AppSettingsError.storageError:
        return 'ストレージエラーが発生しました';
      case AppSettingsError.syncError:
        return '同期エラーが発生しました';
      case AppSettingsError.nostrConnectionError:
        return 'Nostr接続エラーが発生しました';
      case AppSettingsError.amberError:
        return 'Amber連携エラーが発生しました';
      case AppSettingsError.invalidValue:
        return '無効な値が指定されました';
      case AppSettingsError.unexpected:
        return '予期しないエラーが発生しました';
    }
  }
  
  /// Failureを生成
  AppSettingsFailure toFailure([String? customMessage]) {
    return AppSettingsFailure(this, customMessage ?? message);
  }
}

