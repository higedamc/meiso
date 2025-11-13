import '../../../../core/common/failure.dart';

/// CustomListのドメインエラー
enum CustomListError {
  /// リストが見つからない
  notFound,
  
  /// 同じIDのリストが既に存在
  alreadyExists,
  
  /// リスト名が無効
  invalidName,
  
  /// グループメンバーが無効
  invalidMembers,
  
  /// ネットワークエラー
  networkError,
  
  /// 認証エラー
  unauthorized,
  
  /// MLSエラー
  mlsError,
  
  /// 予期しないエラー
  unknown,
}

/// CustomListのFailure実装
class CustomListFailure extends Failure {
  final CustomListError error;
  
  const CustomListFailure(this.error, String message) : super(message);
  
  /// エラーコードからFailureを生成
  factory CustomListFailure.fromError(CustomListError error) {
    String message;
    switch (error) {
      case CustomListError.notFound:
        message = 'リストが見つかりませんでした';
        break;
      case CustomListError.alreadyExists:
        message = '同じIDのリストが既に存在します';
        break;
      case CustomListError.invalidName:
        message = 'リスト名が無効です';
        break;
      case CustomListError.invalidMembers:
        message = 'グループメンバーが無効です';
        break;
      case CustomListError.networkError:
        message = 'ネットワーク接続を確認してください';
        break;
      case CustomListError.unauthorized:
        message = 'この操作を実行する権限がありません';
        break;
      case CustomListError.mlsError:
        message = 'MLSグループの操作に失敗しました';
        break;
      case CustomListError.unknown:
        message = '予期しないエラーが発生しました';
        break;
    }
    return CustomListFailure(error, message);
  }
}

/// ローカルストレージエラー
class CustomListLocalStorageFailure extends Failure {
  const CustomListLocalStorageFailure(String message) : super(message);
}

/// ネットワークエラー
class CustomListNetworkFailure extends Failure {
  const CustomListNetworkFailure(String message) : super(message);
}

/// MLSエラー
class CustomListMlsFailure extends Failure {
  const CustomListMlsFailure(String message) : super(message);
}

