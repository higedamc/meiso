import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';

void main() {
  group('TodoTitle', () {
    group('create', () {
      test('正常な文字列からTodoTitleを作成できる', () {
        // Act
        final result = TodoTitle.create('買い物');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should succeed'),
          (title) => expect(title.value, '買い物'),
        );
      });

      test('前後の空白をトリムして作成できる', () {
        // Act
        final result = TodoTitle.create('  買い物  ');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should succeed'),
          (title) => expect(title.value, '買い物'),
        );
      });

      test('空文字列はValidationFailureを返す', () {
        // Act
        final result = TodoTitle.create('');

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, 'タイトルを入力してください');
          },
          (_) => fail('Should fail'),
        );
      });

      test('空白のみの文字列はValidationFailureを返す', () {
        // Act
        final result = TodoTitle.create('   ');

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, 'タイトルを入力してください');
          },
          (_) => fail('Should fail'),
        );
      });

      test('500文字以下はOK', () {
        // Arrange
        final longText = 'a' * 500;

        // Act
        final result = TodoTitle.create(longText);

        // Assert
        expect(result.isRight(), true);
      });

      test('501文字以上はValidationFailureを返す', () {
        // Arrange
        final tooLongText = 'a' * 501;

        // Act
        final result = TodoTitle.create(tooLongText);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, 'タイトルは500文字以内にしてください');
          },
          (_) => fail('Should fail'),
        );
      });
    });

    group('unsafe', () {
      test('バリデーションなしでTodoTitleを作成できる', () {
        // Act
        final title = TodoTitle.unsafe('');

        // Assert
        expect(title.value, '');
      });

      test('長すぎる文字列でも作成できる', () {
        // Arrange
        final tooLongText = 'a' * 600;

        // Act
        final title = TodoTitle.unsafe(tooLongText);

        // Assert
        expect(title.value, tooLongText);
      });
    });

    group('equality', () {
      test('同じ値のTodoTitleは等しい', () {
        // Arrange
        final title1 = TodoTitle.unsafe('買い物');
        final title2 = TodoTitle.unsafe('買い物');

        // Assert
        expect(title1, title2);
        expect(title1.hashCode, title2.hashCode);
      });

      test('異なる値のTodoTitleは等しくない', () {
        // Arrange
        final title1 = TodoTitle.unsafe('買い物');
        final title2 = TodoTitle.unsafe('掃除');

        // Assert
        expect(title1, isNot(title2));
      });
    });

    group('toString', () {
      test('valueが文字列として返される', () {
        // Arrange
        final title = TodoTitle.unsafe('買い物');

        // Assert
        expect(title.toString(), '買い物');
      });
    });
  });
}
