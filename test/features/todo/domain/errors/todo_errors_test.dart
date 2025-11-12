import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';

void main() {
  group('TodoFailure', () {
    test('notFound has correct message', () {
      final failure = TodoFailure(TodoError.notFound);
      expect(failure.message, 'タスクが見つかりませんでした');
    });

    test('alreadyExists has correct message', () {
      final failure = TodoFailure(TodoError.alreadyExists);
      expect(failure.message, 'タスクは既に存在します');
    });

    test('invalidTitle has correct message', () {
      final failure = TodoFailure(TodoError.invalidTitle);
      expect(failure.message, 'タイトルが無効です');
    });

    test('syncFailed has correct message', () {
      final failure = TodoFailure(TodoError.syncFailed);
      expect(failure.message, '同期に失敗しました');
    });

    test('encryptionFailed has correct message', () {
      final failure = TodoFailure(TodoError.encryptionFailed);
      expect(failure.message, '暗号化に失敗しました');
    });

    test('decryptionFailed has correct message', () {
      final failure = TodoFailure(TodoError.decryptionFailed);
      expect(failure.message, '復号化に失敗しました');
    });

    test('invalidRecurrence has correct message', () {
      final failure = TodoFailure(TodoError.invalidRecurrence);
      expect(failure.message, '繰り返し設定が無効です');
    });

    test('deleteRecurringFailed has correct message', () {
      final failure = TodoFailure(TodoError.deleteRecurringFailed);
      expect(failure.message, '繰り返しタスクの削除に失敗しました');
    });

    test('failures with same error are equal', () {
      final failure1 = TodoFailure(TodoError.notFound);
      final failure2 = TodoFailure(TodoError.notFound);
      expect(failure1, equals(failure2));
    });

    test('failures with different errors are not equal', () {
      final failure1 = TodoFailure(TodoError.notFound);
      final failure2 = TodoFailure(TodoError.syncFailed);
      expect(failure1, isNot(equals(failure2)));
    });

    test('hashCode is based on error', () {
      final failure1 = TodoFailure(TodoError.notFound);
      final failure2 = TodoFailure(TodoError.notFound);
      expect(failure1.hashCode, equals(failure2.hashCode));
    });

    test('toString returns message', () {
      final failure = TodoFailure(TodoError.notFound);
      expect(failure.toString(), 'タスクが見つかりませんでした');
    });
  });
}

