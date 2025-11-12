import '../../../../core/common/failure.dart';

/// Todo機能固有のエラー
class TodoFailure extends Failure {
  TodoFailure(this.error) : super(_errorMessage(error));

  final TodoError error;

  static String _errorMessage(TodoError error) {
    switch (error) {
      case TodoError.notFound:
        return 'タスクが見つかりませんでした';
      case TodoError.alreadyExists:
        return 'タスクは既に存在します';
      case TodoError.invalidTitle:
        return 'タイトルが無効です';
      case TodoError.syncFailed:
        return '同期に失敗しました';
      case TodoError.encryptionFailed:
        return '暗号化に失敗しました';
      case TodoError.decryptionFailed:
        return '復号化に失敗しました';
      case TodoError.invalidRecurrence:
        return '繰り返し設定が無効です';
      case TodoError.deleteRecurringFailed:
        return '繰り返しタスクの削除に失敗しました';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoFailure &&
        other.runtimeType == runtimeType &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(runtimeType, error);
}

/// Todo機能のエラー種別
enum TodoError {
  /// タスクが見つからない
  notFound,

  /// タスクが既に存在
  alreadyExists,

  /// タイトルが無効
  invalidTitle,

  /// 同期失敗
  syncFailed,

  /// 暗号化失敗
  encryptionFailed,

  /// 復号化失敗
  decryptionFailed,

  /// 繰り返し設定が無効
  invalidRecurrence,

  /// 繰り返しタスクの削除失敗
  deleteRecurringFailed,
}

