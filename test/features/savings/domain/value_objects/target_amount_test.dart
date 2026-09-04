import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/savings/domain/value_objects/target_amount.dart';

void main() {
  group('TargetAmount', () {
    group('create', () {
      test('1 sat以上ならTargetAmountを作成できる', () {
        final result = TargetAmount.create(1000);

        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should succeed'),
          (amount) => expect(amount.sats, 1000),
        );
      });

      test('0 satはValidationFailureを返す', () {
        final result = TargetAmount.create(0);

        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, '目標額は1 sat以上にしてください');
          },
          (_) => fail('Should fail'),
        );
      });

      test('負数はValidationFailureを返す', () {
        final result = TargetAmount.create(-1);

        expect(result.isLeft(), true);
      });

      test('上限（1 BTC）ちょうどはOK', () {
        final result = TargetAmount.create(TargetAmount.maxSats);

        expect(result.isRight(), true);
      });

      test('上限を超えるとValidationFailureを返す', () {
        final result = TargetAmount.create(TargetAmount.maxSats + 1);

        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, '目標額は1 BTC（100,000,000 sat）以内にしてください');
          },
          (_) => fail('Should fail'),
        );
      });
    });

    group('equality', () {
      test('同じ値は等しい', () {
        final a = TargetAmount.unsafe(500);
        final b = TargetAmount.unsafe(500);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('異なる値は等しくない', () {
        final a = TargetAmount.unsafe(500);
        final b = TargetAmount.unsafe(600);

        expect(a, isNot(b));
      });
    });
  });
}
