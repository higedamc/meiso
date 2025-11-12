import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/create_todo_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late CreateTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = CreateTodoUseCase(mockRepository);
  });

  group('CreateTodoUseCase', () {
    final testTitle = TodoTitle.unsafe('Test Todo');
    final testDate = TodoDate.dateOnly(DateTime(2025, 11, 12));

    test('タイトルのみで正常にTodoが作成される', () async {
      // Arrange
      final params = CreateTodoParams(title: testTitle.value);
      
      when(() => mockRepository.createTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo.copyWith(id: 'test-id-1'));
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.id, 'test-id-1');
          expect(todo.title.value, testTitle.value);
          expect(todo.completed, false);
          expect(todo.date, null);
        },
      );

      verify(() => mockRepository.createTodo(any())).called(1);
    });

    test('日付付きでTodoが作成される', () async {
      // Arrange
      final params = CreateTodoParams(
        title: testTitle.value,
        date: testDate,
      );

      when(() => mockRepository.createTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo.copyWith(id: 'test-id-2'));
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.date, testDate);
        },
      );
    });

    test('カスタムリスト付きでTodoが作成される', () async {
      // Arrange
      final params = CreateTodoParams(
        title: testTitle.value,
        customListId: 'Shopping',
      );

      when(() => mockRepository.createTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo.copyWith(id: 'test-id-3'));
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.customListId, 'Shopping');
        },
      );
    });

    test('空のタイトルでバリデーションエラーが返る', () async {
      // Arrange
      final params = CreateTodoParams(title: '');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, contains('タイトル'));
        },
        (_) => fail('Should fail'),
      );

      verifyNever(() => mockRepository.createTodo(any()));
    });

    test('長すぎるタイトルでバリデーションエラーが返る', () async {
      // Arrange
      final longTitle = 'a' * 501;
      final params = CreateTodoParams(title: longTitle);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, contains('500'));
        },
        (_) => fail('Should fail'),
      );

      verifyNever(() => mockRepository.createTodo(any()));
    });

    test('Repository失敗時にエラーが返る', () async {
      // Arrange
      final params = CreateTodoParams(title: testTitle.value);

      when(() => mockRepository.createTodo(any())).thenAnswer(
        (_) async => Left(ServerFailure('Database error')),
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
        },
        (_) => fail('Should fail'),
      );
    });

    test('order指定でTodoが作成される', () async {
      // Arrange
      final params = CreateTodoParams(
        title: testTitle.value,
        order: 1,
      );

      when(() => mockRepository.createTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo.copyWith(id: 'test-id-4'));
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.order, 1);
        },
      );
    });
  });
}

