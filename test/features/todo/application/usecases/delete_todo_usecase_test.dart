import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/delete_todo_usecase.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late DeleteTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = DeleteTodoUseCase(mockRepository);
  });

  group('DeleteTodoUseCase', () {
    test('正常にTodoが削除される', () async {
      // Arrange
      final params = DeleteTodoParams(todoId: 'test-id-1');

      when(() => mockRepository.deleteTodo('test-id-1'))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockRepository.deleteTodo('test-id-1')).called(1);
    });

    test('存在しないTodoIDでエラーが返る', () async {
      // Arrange
      final params = DeleteTodoParams(todoId: 'non-existent-id');

      when(() => mockRepository.deleteTodo('non-existent-id'))
          .thenAnswer((_) async => Left(TodoFailure(TodoError.notFound)));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<TodoFailure>());
        },
        (_) => fail('Should fail'),
      );

      verify(() => mockRepository.deleteTodo('non-existent-id')).called(1);
    });

    test('Repository削除失敗時にエラーが返る', () async {
      // Arrange
      final params = DeleteTodoParams(todoId: 'test-id-1');

      when(() => mockRepository.deleteTodo('test-id-1'))
          .thenAnswer((_) async => Left(ServerFailure('Delete failed')));

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
  });
}

