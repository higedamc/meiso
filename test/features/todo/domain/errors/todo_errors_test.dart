import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';

void main() {
  group('TodoError', () {
    test('全てのエラー種別が定義されている', () {
      // Assert
      expect(TodoError.values.length, 8);
      expect(TodoError.values, contains(TodoError.notFound));
      expect(TodoError.values, contains(TodoError.alreadyExists));
      expect(TodoError.values, contains(TodoError.invalidTitle));
      expect(TodoError.values, contains(TodoError.syncFailed));
      expect(TodoError.values, contains(TodoError.encryptionFailed));
      expect(TodoError.values, contains(TodoError.decryptionFailed));
      expect(TodoError.values, contains(TodoError.recurringInstanceError));
      expect(TodoError.values, contains(TodoError.linkPreviewError));
    });
  });

  group('TodoFailure', () {
    test('notFoundエラーは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.notFound);

      // Assert
      expect(failure.message, 'タスクが見つかりませんでした');
      expect(failure.error, TodoError.notFound);
    });

    test('alreadyExistsエラーは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.alreadyExists);

      // Assert
      expect(failure.message, 'タスクは既に存在します');
      expect(failure.error, TodoError.alreadyExists);
    });

    test('invalidTitleエラーは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.invalidTitle);

      // Assert
      expect(failure.message, 'タイトルが無効です');
      expect(failure.error, TodoError.invalidTitle);
    });

    test('syncFailedエラーは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.syncFailed);

      // Assert
      expect(failure.message, '同期に失敗しました');
      expect(failure.error, TodoError.syncFailed);
    });

    test('encryptionFailedエラーは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.encryptionFailed);

      // Assert
      expect(failure.message, '暗号化に失敗しました');
      expect(failure.error, TodoError.encryptionFailed);
    });

    test('decryptionFailedエラーは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.decryptionFailed);

      // Assert
      expect(failure.message, '復号化に失敗しました');
      expect(failure.error, TodoError.decryptionFailed);
    });

    test('recurringInstanceErrorは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.recurringInstanceError);

      // Assert
      expect(failure.message, '繰り返しタスクの操作に失敗しました');
      expect(failure.error, TodoError.recurringInstanceError);
    });

    test('linkPreviewErrorは適切なメッセージを持つ', () {
      // Arrange & Act
      const failure = TodoFailure(TodoError.linkPreviewError);

      // Assert
      expect(failure.message, 'リンクプレビューの取得に失敗しました');
      expect(failure.error, TodoError.linkPreviewError);
    });

    group('equality', () {
      test('同じエラー種別のTodoFailureは等しい', () {
        // Arrange
        const failure1 = TodoFailure(TodoError.notFound);
        const failure2 = TodoFailure(TodoError.notFound);

        // Assert
        expect(failure1, failure2);
        expect(failure1.hashCode, failure2.hashCode);
      });

      test('異なるエラー種別のTodoFailureは等しくない', () {
        // Arrange
        const failure1 = TodoFailure(TodoError.notFound);
        const failure2 = TodoFailure(TodoError.syncFailed);

        // Assert
        expect(failure1, isNot(failure2));
      });
    });

    test('toStringはメッセージを返す', () {
      // Arrange
      const failure = TodoFailure(TodoError.notFound);

      // Assert
      expect(failure.toString(), 'タスクが見つかりませんでした');
    });
  });
}
