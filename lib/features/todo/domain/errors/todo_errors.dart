import '../../../../core/common/failure.dart';

/// Todo機能固有のエラー種別
enum TodoError {
  /// タスクが見つからない
  notFound,
  
  /// タスクが既に存在する（ID重複）
  alreadyExists,
  
  /// タイトルが無効
  invalidTitle,
  
  /// 同期に失敗
  syncFailed,
  
  /// 暗号化に失敗
  encryptionFailed,
  
  /// 復号化に失敗
  decryptionFailed,
  
  /// 繰り返しタスクのインスタンスエラー
  recurringInstanceError,
  
  /// リンクプレビューの取得エラー
  linkPreviewError,
}

/// Todo機能固有のFailure
class TodoFailure extends Failure {
  const TodoFailure(this.error, {String? customMessage}) 
      : super(customMessage ?? '');

  final TodoError error;

  @override
  String get message => _errorMessage(error);

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
      case TodoError.recurringInstanceError:
        return '繰り返しタスクの操作に失敗しました';
      case TodoError.linkPreviewError:
        return 'リンクプレビューの取得に失敗しました';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoFailure && error == other.error;

  @override
  int get hashCode => Object.hash(runtimeType, error);
}

