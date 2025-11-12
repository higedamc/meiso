import 'package:dartz/dartz.dart';
import 'failure.dart';

/// UseCaseの基底クラス
///
/// すべてのUseCaseはこのインターフェースを実装する
/// Type: 成功時の戻り値の型
/// Params: UseCaseに渡すパラメータの型
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// パラメータが不要なUseCase用
class NoParams {
  const NoParams();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoParams;
  }

  @override
  int get hashCode => 0;
}

