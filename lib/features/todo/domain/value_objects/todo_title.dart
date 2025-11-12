import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';

/// Todoのタイトル（Value Object）
/// 
/// ビジネスルール:
/// - 空文字列は不可
/// - 最大500文字
class TodoTitle {
  const TodoTitle._(this.value);

  final String value;

  /// バリデーション付きファクトリー
  /// 
  /// ユーザー入力から TodoTitle を作成する際に使用。
  /// バリデーションエラーの場合は Left(ValidationFailure) を返す。
  static Either<Failure, TodoTitle> create(String input) {
    final trimmed = input.trim();
    
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('タイトルを入力してください'));
    }
    
    if (trimmed.length > 500) {
      return const Left(ValidationFailure('タイトルは500文字以内にしてください'));
    }
    
    return Right(TodoTitle._(trimmed));
  }

  /// 検証なしで作成（既存データ読み込み時）
  /// 
  /// ローカルストレージやNostrから読み込んだデータは
  /// すでにバリデーション済みと仮定して使用。
  factory TodoTitle.unsafe(String value) => TodoTitle._(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoTitle && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

