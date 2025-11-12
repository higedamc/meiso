import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/sync_to_nostr_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late SyncToNostrUseCase usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = SyncToNostrUseCase(mockRepository);
  });

  group('SyncToNostrUseCase', () {
    final testTodo = Todo(
      id: 'test-id-1',
      title: TodoTitle.unsafe('Test Todo'),
      completed: false,
      createdAt: DateTime(2025, 11, 12),
      updatedAt: DateTime(2025, 11, 12),
      date: null,
      customListId: null,
      order: 0,
      linkPreview: null,
      recurrence: null,
      parentRecurringId: null,
      eventId: null,
      needsSync: false,
    );

    test('TodoがNostrに正常に同期される', () async {
      // Arrange
      final params = SyncToNostrParams(todo: testTodo);

      when(() => mockRepository.syncToNostr(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockRepository.syncToNostr(testTodo)).called(1);
    });

    test('Nostr接続失敗時にエラーが返る', () async {
      // Arrange
      final params = SyncToNostrParams(todo: testTodo);

      when(() => mockRepository.syncToNostr(any()))
          .thenAnswer((_) async => Left(NetworkFailure('Connection timeout')));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
        },
        (_) => fail('Should fail'),
      );
    });

    test('Nostr認証失敗時にエラーが返る', () async {
      // Arrange
      final params = SyncToNostrParams(todo: testTodo);

      when(() => mockRepository.syncToNostr(any()))
          .thenAnswer((_) async => Left(AuthFailure('Invalid credentials')));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
        },
        (_) => fail('Should fail'),
      );
    });

    test('暗号化失敗時にエラーが返る', () async {
      // Arrange
      final params = SyncToNostrParams(todo: testTodo);

      when(() => mockRepository.syncToNostr(any()))
          .thenAnswer((_) async => Left(EncryptionFailure('Encryption failed')));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<EncryptionFailure>());
        },
        (_) => fail('Should fail'),
      );
    });
  });
}

