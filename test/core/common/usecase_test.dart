import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:meiso/core/common/usecase.dart';
import 'package:meiso/core/common/failure.dart';

// テスト用のUseCase実装
class TestUseCase implements UseCase<String, TestParams> {
  @override
  Future<Either<Failure, String>> call(TestParams params) async {
    if (params.shouldFail) {
      return const Left(NetworkFailure('テスト失敗'));
    }
    return Right('成功: ${params.input}');
  }
}

class TestParams {
  const TestParams({required this.input, this.shouldFail = false});
  final String input;
  final bool shouldFail;
}

// パラメータなしのUseCase
class NoParamsTestUseCase implements UseCase<int, NoParams> {
  @override
  Future<Either<Failure, int>> call(NoParams params) async {
    return const Right(42);
  }
}

void main() {
  group('UseCase', () {
    late TestUseCase useCase;

    setUp(() {
      useCase = TestUseCase();
    });

    test('UseCase returns Right on success', () async {
      // Arrange
      const params = TestParams(input: 'テスト');

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not be left'),
        (value) => expect(value, '成功: テスト'),
      );
    });

    test('UseCase returns Left on failure', () async {
      // Arrange
      const params = TestParams(input: 'テスト', shouldFail: true);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (value) => fail('Should not be right'),
      );
    });

    test('NoParams UseCase works correctly', () async {
      // Arrange
      final noParamsUseCase = NoParamsTestUseCase();

      // Act
      final result = await noParamsUseCase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not be left'),
        (value) => expect(value, 42),
      );
    });

    test('NoParams instances are equal', () {
      const params1 = NoParams();
      const params2 = NoParams();
      expect(params1, equals(params2));
    });

    test('NoParams hashCode is consistent', () {
      const params1 = NoParams();
      const params2 = NoParams();
      expect(params1.hashCode, equals(params2.hashCode));
    });
  });

  group('Either integration', () {
    test('fold executes correct function', () async {
      final useCase = TestUseCase();

      // Success case
      final successResult = await useCase(const TestParams(input: 'test'));
      final successValue = successResult.fold(
        (l) => 'failure',
        (r) => r,
      );
      expect(successValue, '成功: test');

      // Failure case
      final failureResult =
          await useCase(const TestParams(input: 'test', shouldFail: true));
      final failureValue = failureResult.fold(
        (l) => l.message,
        (r) => 'success',
      );
      expect(failureValue, 'テスト失敗');
    });

    test('getOrElse returns value or default', () async {
      final useCase = TestUseCase();

      // Success case
      final successResult = await useCase(const TestParams(input: 'test'));
      final successValue = successResult.getOrElse(() => 'default');
      expect(successValue, '成功: test');

      // Failure case
      final failureResult =
          await useCase(const TestParams(input: 'test', shouldFail: true));
      final failureValue = failureResult.getOrElse(() => 'default');
      expect(failureValue, 'default');
    });

    test('map transforms Right value', () async {
      final useCase = TestUseCase();
      final result = await useCase(const TestParams(input: 'test'));

      final mapped = result.map((r) => r.length);

      expect(mapped.isRight(), true);
      mapped.fold(
        (l) => fail('Should not be left'),
        (r) => expect(r, '成功: test'.length),
      );
    });
  });
}

