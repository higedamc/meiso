import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/core/common/usecase.dart';
import 'package:meiso/features/todo/application/usecases/sync_from_nostr_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late SyncFromNostrUseCase usecase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = SyncFromNostrUseCase(mockRepository);
  });

  group('SyncFromNostrUseCase', () {
    final syncedTodos = <Todo>[
      Todo(
        id: 'test-id-1',
        title: TodoTitle.unsafe('Synced Todo 1'),
        completed: false,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        date: null,
        customListId: null,
        order: 0,
        linkPreview: null,
        recurrence: null,
        parentRecurringId: null,
        eventId: 'event-1',
      needsSync: false,
      ),
      Todo(
        id: 'test-id-2',
        title: TodoTitle.unsafe('Synced Todo 2'),
        completed: true,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        date: null,
        customListId: null,
        order: 1,
        linkPreview: null,
        recurrence: null,
        parentRecurringId: null,
        eventId: 'event-2',
      needsSync: false,
      ),
    ];

    test('NostrからTodoが正常に同期される', () async {
      // Arrange
      when(() => mockRepository.syncFromNostr())
          .thenAnswer((_) async => Right(syncedTodos));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos.length, 2);
          expect(todos[0].eventId, isNotNull);
          expect(todos[1].eventId, isNotNull);
        },
      );

      verify(() => mockRepository.syncFromNostr()).called(1);
    });

    test('Nostr同期で空リストが返る', () async {
      // Arrange
      when(() => mockRepository.syncFromNostr())
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos.isEmpty, true);
        },
      );
    });

    test('Nostr接続失敗時にエラーが返る', () async {
      // Arrange
      when(() => mockRepository.syncFromNostr())
          .thenAnswer((_) async => Left(NetworkFailure('Connection timeout')));

      // Act
      final result = await usecase(const NoParams());

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
      when(() => mockRepository.syncFromNostr())
          .thenAnswer((_) async => Left(AuthFailure('Invalid credentials')));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
        },
        (_) => fail('Should fail'),
      );
    });
  });
}

