import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/utils/todo_absence_resolution.dart';

/// Causal deletion inference (PLANS/MEISO_TASK_LOSS_FIX_PLAN.md, decision 2).
///
/// Each test names its negative control: what the old 24-hour rule did with
/// the same input.
void main() {
  // 2026-01-01T12:00:00Z
  final localUpdatedAt = DateTime.utc(2026, 1, 1, 12);
  final localUpdatedSec = localUpdatedAt.millisecondsSinceEpoch ~/ 1000;

  group('resolveAbsentTodo', () {
    test('no snapshot for the list keeps the task, however old it is', () {
      // Negative control: the 24-hour rule deleted any task absent from the
      // fetch once its updatedAt was older than a day, which is exactly this
      // input when the fetch simply did not return the list.
      final old = DateTime.utc(2025, 6, 15);
      expect(
        resolveAbsentTodo(listCreatedAt: null, localUpdatedAt: old),
        AbsentTodoResolution.keepNoEvidence,
      );
    });

    test('a list older than the local edit keeps the task and resyncs', () {
      // The relays hold a version of the list that predates the edit; the
      // edit must be published again, not thrown away.
      expect(
        resolveAbsentTodo(
          listCreatedAt: localUpdatedSec - 1,
          localUpdatedAt: localUpdatedAt,
        ),
        AbsentTodoResolution.keepAndResync,
      );
    });

    test('a list newer than the local edit drops the task', () {
      // Positive evidence: the list was rewritten after the edit and the
      // task is not in it.
      expect(
        resolveAbsentTodo(
          listCreatedAt: localUpdatedSec + 1,
          localUpdatedAt: localUpdatedAt,
        ),
        AbsentTodoResolution.drop,
      );
    });

    test('the same second is concurrent, not newer', () {
      // created_at has second resolution; a sub-second difference in either
      // direction lands on the same value, so it cannot prove ordering.
      expect(
        resolveAbsentTodo(
          listCreatedAt: localUpdatedSec,
          localUpdatedAt: localUpdatedAt.add(const Duration(milliseconds: 900)),
        ),
        AbsentTodoResolution.keepAndResync,
      );
    });

    test('a local timestamp in local time compares by instant', () {
      // updatedAt is stored in local time; the comparison must not depend on
      // the device's zone.
      final localZone = localUpdatedAt.toLocal();
      expect(
        resolveAbsentTodo(
          listCreatedAt: localUpdatedSec + 1,
          localUpdatedAt: localZone,
        ),
        AbsentTodoResolution.drop,
      );
      expect(
        resolveAbsentTodo(
          listCreatedAt: localUpdatedSec - 1,
          localUpdatedAt: localZone,
        ),
        AbsentTodoResolution.keepAndResync,
      );
    });

    test('age of the edit alone never decides', () {
      // A task edited a week ago survives when the only list we have is
      // older still; the 24-hour rule would have deleted it.
      final weekOld = DateTime.utc(2025, 12, 25);
      expect(
        resolveAbsentTodo(
          listCreatedAt: weekOld.millisecondsSinceEpoch ~/ 1000 - 3600,
          localUpdatedAt: weekOld,
        ),
        AbsentTodoResolution.keepAndResync,
      );
    });
  });

}
