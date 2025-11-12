import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';

/// カスタムリスト名のValue Object
///
/// ビジネスルール:
/// - 空文字列禁止
/// - 最大50文字
/// - 自動的に大文字に変換
class ListName {
  const ListName._(this.value);
  
  final String value;
  
  /// バリデーション付きファクトリー
  static Either<Failure, ListName> create(String input) {
    final trimmed = input.trim();
    
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('リスト名を入力してください'));
    }
    
    if (trimmed.length > 50) {
      return const Left(ValidationFailure('リスト名は50文字以内にしてください'));
    }
    
    // 大文字に変換
    final uppercased = trimmed.toUpperCase();
    
    return Right(ListName._(uppercased));
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListName && runtimeType == other.runtimeType && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
  
  @override
  String toString() => value;
}

