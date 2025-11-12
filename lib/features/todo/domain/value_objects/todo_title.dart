import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/config/app_config.dart';

/// Todoのタイトル（Value Object）
///
/// ビジネスルールでバリデーションを行う
class TodoTitle {
  const TodoTitle._(this.value);

  final String value;

  /// バリデーション付きファクトリー
  ///
  /// ユーザー入力からTodoTitleを作成する際に使用
  static Either<Failure, TodoTitle> create(String input) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('タイトルを入力してください'));
    }

    if (trimmed.length > AppConfig.maxTodoTitleLength) {
      return Left(ValidationFailure(
          'タイトルは${AppConfig.maxTodoTitleLength}文字以内にしてください'));
    }

    return Right(TodoTitle._(trimmed));
  }

  /// 検証なしで作成（既存データ読み込み時用）
  ///
  /// データベースやNostrから取得したデータは既にバリデーション済みと想定
  factory TodoTitle.unsafe(String value) => TodoTitle._(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoTitle && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

