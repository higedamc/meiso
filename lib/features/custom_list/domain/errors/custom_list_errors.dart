import '../../../../core/common/failure.dart';

/// カスタムリスト関連のエラー種別
enum CustomListError {
  /// リストが見つからない
  notFound,
  
  /// 同じ名前のリストが既に存在
  duplicateName,
  
  /// リストが空（デフォルトリスト作成対象外）
  notEmpty,
  
  /// ストレージエラー
  storageError,
  
  /// 同期エラー
  syncError,
  
  /// 予期しないエラー
  unexpected,
}

/// CustomListに関するFailure
class CustomListFailure extends Failure {
  const CustomListFailure(this.error, String message) : super(message);
  
  final CustomListError error;
  
  @override
  String toString() => 'CustomListFailure(error: $error, message: $message)';
}

/// CustomListの拡張メソッド
extension CustomListErrorExtension on CustomListError {
  /// エラーメッセージを取得
  String get message {
    switch (this) {
      case CustomListError.notFound:
        return 'リストが見つかりませんでした';
      case CustomListError.duplicateName:
        return '同じ名前のリストが既に存在します';
      case CustomListError.notEmpty:
        return 'リストが既に存在します';
      case CustomListError.storageError:
        return 'ストレージエラーが発生しました';
      case CustomListError.syncError:
        return '同期エラーが発生しました';
      case CustomListError.unexpected:
        return '予期しないエラーが発生しました';
    }
  }
  
  /// Failureを生成
  CustomListFailure toFailure([String? customMessage]) {
    return CustomListFailure(this, customMessage ?? message);
  }
}

