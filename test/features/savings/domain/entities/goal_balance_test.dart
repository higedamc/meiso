import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/savings/domain/entities/goal_balance.dart';

void main() {
  group('GoalBalance', () {
    GoalBalance balance(int current, int target) => GoalBalance(
      goalId: 'g1',
      currentSats: current,
      targetSats: target,
    );

    group('progress', () {
      test('半分貯まっていれば0.5', () {
        expect(balance(500, 1000).progress, 0.5);
      });

      test('0なら0.0', () {
        expect(balance(0, 1000).progress, 0.0);
      });

      test('超過しても1.0でクランプされる', () {
        expect(balance(1500, 1000).progress, 1.0);
      });

      test('targetが0なら0.0（ゼロ除算回避）', () {
        expect(balance(100, 0).progress, 0.0);
      });
    });

    group('isReached', () {
      test('目標到達でtrue', () {
        expect(balance(1000, 1000).isReached, true);
        expect(balance(1200, 1000).isReached, true);
      });

      test('未達でfalse', () {
        expect(balance(999, 1000).isReached, false);
      });

      test('targetが0ならfalse', () {
        expect(balance(0, 0).isReached, false);
      });
    });

    group('remainingSats', () {
      test('残額を返す', () {
        expect(balance(300, 1000).remainingSats, 700);
      });

      test('超過しても0未満にはならない', () {
        expect(balance(1200, 1000).remainingSats, 0);
      });
    });
  });
}
