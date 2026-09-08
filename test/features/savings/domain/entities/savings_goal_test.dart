import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/savings/domain/entities/savings_goal.dart';

void main() {
  group('SavingsGoal', () {
    SavingsGoal goal({DateTime? deadline}) => SavingsGoal(
      goalId: 'trip-fund',
      name: 'TRIP FUND',
      targetSats: 100000,
      mintUrl: 'https://mint.example',
      deadline: deadline,
      createdAt: DateTime(2026),
    );

    test('dTagはプレフィックス付きで生成される', () {
      expect(goal().dTag, 'meiso-savings-trip-fund');
    });

    test('デフォルトは個人・sat建て', () {
      final g = goal();
      expect(g.isCollaborative, false);
      expect(g.currency, 'sat');
      expect(g.p2pkPubkey, isNull);
    });

    group('isPastDeadline', () {
      test('期日未設定なら常にfalse', () {
        expect(goal().isPastDeadline(DateTime(2030)), false);
      });

      test('期日前はfalse', () {
        final g = goal(deadline: DateTime(2026, 12, 31));
        expect(g.isPastDeadline(DateTime(2026, 6)), false);
      });

      test('期日後はtrue', () {
        final g = goal(deadline: DateTime(2026, 1, 31));
        expect(g.isPastDeadline(DateTime(2026, 2)), true);
      });
    });

    test('JSONラウンドトリップで等価', () {
      final g = goal(deadline: DateTime(2026, 12, 31));
      final restored = SavingsGoal.fromJson(g.toJson());
      expect(restored, g);
    });
  });
}
