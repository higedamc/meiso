import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/core/config/app_config.dart';

void main() {
  group('TodoTitle', () {
    group('create', () {
      test('空文字列はValidationFailureを返す', () {
        final result = TodoTitle.create('');
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, 'タイトルを入力してください');
          },
          (title) => fail('Should be Left'),
        );
      });

      test('空白文字のみの文字列はValidationFailureを返す', () {
        final result = TodoTitle.create('   ');
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(failure.message, 'タイトルを入力してください');
          },
          (title) => fail('Should be Left'),
        );
      });

      test('最大文字数を超えるとValidationFailureを返す', () {
        final longString = 'a' * (AppConfig.maxTodoTitleLength + 1);
        final result = TodoTitle.create(longString);
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            expect(
                failure.message,
                'タイトルは${AppConfig.maxTodoTitleLength}文字以内にしてください');
          },
          (title) => fail('Should be Left'),
        );
      });

      test('正常な文字列はTodoTitleを返す', () {
        final result = TodoTitle.create('買い物');
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (title) {
            expect(title.value, '買い物');
          },
        );
      });

      test('前後の空白はトリムされる', () {
        final result = TodoTitle.create('  買い物  ');
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (title) {
            expect(title.value, '買い物');
          },
        );
      });

      test('最大文字数ちょうどは成功する', () {
        final exactString = 'a' * AppConfig.maxTodoTitleLength;
        final result = TodoTitle.create(exactString);
        expect(result.isRight(), true);
      });

      test('絵文字を含む文字列は成功する', () {
        final result = TodoTitle.create('🎉 誕生日パーティー');
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (title) {
            expect(title.value, '🎉 誕生日パーティー');
          },
        );
      });

      test('改行を含む文字列は成功する', () {
        final result = TodoTitle.create('タスク1\nタスク2');
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (title) {
            expect(title.value, 'タスク1\nタスク2');
          },
        );
      });
    });

    group('unsafe', () {
      test('バリデーションなしでTodoTitleを作成できる', () {
        final title = TodoTitle.unsafe('任意の文字列');
        expect(title.value, '任意の文字列');
      });

      test('空文字列でも作成できる', () {
        final title = TodoTitle.unsafe('');
        expect(title.value, '');
      });

      test('最大文字数を超えても作成できる', () {
        final longString = 'a' * 1000;
        final title = TodoTitle.unsafe(longString);
        expect(title.value, longString);
      });
    });

    group('equality', () {
      test('同じ値を持つTodoTitleは等しい', () {
        final title1 = TodoTitle.unsafe('買い物');
        final title2 = TodoTitle.unsafe('買い物');
        expect(title1, equals(title2));
      });

      test('異なる値を持つTodoTitleは等しくない', () {
        final title1 = TodoTitle.unsafe('買い物');
        final title2 = TodoTitle.unsafe('掃除');
        expect(title1, isNot(equals(title2)));
      });

      test('hashCodeは値に基づく', () {
        final title1 = TodoTitle.unsafe('買い物');
        final title2 = TodoTitle.unsafe('買い物');
        expect(title1.hashCode, equals(title2.hashCode));
      });
    });

    group('toString', () {
      test('toStringは値を返す', () {
        final title = TodoTitle.unsafe('買い物');
        expect(title.toString(), '買い物');
      });
    });
  });
}

