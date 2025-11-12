import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/core/common/usecase.dart';
import 'package:meiso/features/todo/application/usecases/create_todo_usecase.dart';
import 'package:meiso/features/todo/application/usecases/delete_todo_usecase.dart';
import 'package:meiso/features/todo/application/usecases/get_all_todos_usecase.dart';
import 'package:meiso/features/todo/application/usecases/move_todo_usecase.dart';
import 'package:meiso/features/todo/application/usecases/reorder_todo_usecase.dart';
import 'package:meiso/features/todo/application/usecases/sync_from_nostr_usecase.dart';
import 'package:meiso/features/todo/application/usecases/toggle_todo_usecase.dart';
import 'package:meiso/features/todo/application/usecases/update_todo_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/presentation/view_models/todo_list_view_model.dart';
import 'package:meiso/features/todo/presentation/view_models/todo_list_state.dart';
import 'package:mocktail/mocktail.dart';

// Mock Classes
class MockGetAllTodosUseCase extends Mock implements GetAllTodosUseCase {}

class MockCreateTodoUseCase extends Mock implements CreateTodoUseCase {}

class MockUpdateTodoUseCase extends Mock implements UpdateTodoUseCase {}

class MockDeleteTodoUseCase extends Mock implements DeleteTodoUseCase {}

class MockToggleTodoUseCase extends Mock implements ToggleTodoUseCase {}

class MockReorderTodoUseCase extends Mock implements ReorderTodoUseCase {}

class MockMoveTodoUseCase extends Mock implements MoveTodoUseCase {}

class MockSyncFromNostrUseCase extends Mock implements SyncFromNostrUseCase {}

// Fake Classes for fallback values
class FakeTodo extends Fake implements Todo {}

class FakeCreateTodoParams extends Fake implements CreateTodoParams {}

class FakeUpdateTodoParams extends Fake implements UpdateTodoParams {}

class FakeDeleteTodoParams extends Fake implements DeleteTodoParams {}

class FakeToggleTodoParams extends Fake implements ToggleTodoParams {}

class FakeReorderTodoParams extends Fake implements ReorderTodoParams {}

class FakeMoveTodoParams extends Fake implements MoveTodoParams {}

void main() {
  late MockGetAllTodosUseCase mockGetAllTodosUseCase;
  late MockCreateTodoUseCase mockCreateTodoUseCase;
  late MockUpdateTodoUseCase mockUpdateTodoUseCase;
  late MockDeleteTodoUseCase mockDeleteTodoUseCase;
  late MockToggleTodoUseCase mockToggleTodoUseCase;
  late MockReorderTodoUseCase mockReorderTodoUseCase;
  late MockMoveTodoUseCase mockMoveTodoUseCase;
  late MockSyncFromNostrUseCase mockSyncFromNostrUseCase;
  late TodoListViewModel notifier;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(FakeTodo());
    registerFallbackValue(FakeCreateTodoParams());
    registerFallbackValue(FakeUpdateTodoParams());
    registerFallbackValue(FakeDeleteTodoParams());
    registerFallbackValue(FakeToggleTodoParams());
    registerFallbackValue(FakeReorderTodoParams());
    registerFallbackValue(FakeMoveTodoParams());
  });

  setUp(() {
    mockGetAllTodosUseCase = MockGetAllTodosUseCase();
    mockCreateTodoUseCase = MockCreateTodoUseCase();
    mockUpdateTodoUseCase = MockUpdateTodoUseCase();
    mockDeleteTodoUseCase = MockDeleteTodoUseCase();
    mockToggleTodoUseCase = MockToggleTodoUseCase();
    mockReorderTodoUseCase = MockReorderTodoUseCase();
    mockMoveTodoUseCase = MockMoveTodoUseCase();
    mockSyncFromNostrUseCase = MockSyncFromNostrUseCase();
  });

    TodoListViewModel createNotifier({bool autoLoad = true}) {
      return TodoListViewModel(
      getAllTodosUseCase: mockGetAllTodosUseCase,
      createTodoUseCase: mockCreateTodoUseCase,
      updateTodoUseCase: mockUpdateTodoUseCase,
      deleteTodoUseCase: mockDeleteTodoUseCase,
      toggleTodoUseCase: mockToggleTodoUseCase,
      reorderTodoUseCase: mockReorderTodoUseCase,
      moveTodoUseCase: mockMoveTodoUseCase,
      syncFromNostrUseCase: mockSyncFromNostrUseCase,
      autoLoad: autoLoad,
    );
  }

  group('TodoListViewModel', () {
    group('初期化', () {
      test('初期化時に自動的にloadTodosが呼ばれる', () async {
        // Arrange
        final testTodos = <Todo>[
          Todo(
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
            eventId: 'event-1',
            needsSync: false,
          ),
        ];

        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => Right(testTodos));

        // Act
        notifier = createNotifier();

        // Wait for async initialization
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockGetAllTodosUseCase(const NoParams())).called(1);
        
        // Verify state is loaded
        final isLoaded = notifier.state.maybeMap(
          loaded: (_) => true,
          orElse: () => false,
        );
        expect(isLoaded, true);
      });

      test('初期化時にエラーが発生した場合、errorステートになる', () async {
        // Arrange
        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => Left(CacheFailure('Test error')));

        // Act
        notifier = createNotifier();

        // Wait for async initialization
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        notifier.state.whenOrNull(
          error: (failure) {
            expect(failure, isA<CacheFailure>());
            expect(failure.message, 'Test error');
          },
        );
        
        final isError = notifier.state.maybeMap(
          error: (_) => true,
          orElse: () => false,
        );
        expect(isError, true);
      });
    });

    group('loadTodos', () {
      test('Todoリストが正常に読み込まれる', () async {
        // Arrange
        final testTodos = <Todo>[
          Todo(
            id: 'test-id-1',
            title: TodoTitle.unsafe('Test Todo 1'),
            completed: false,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2025, 11, 12),
            date: TodoDate.dateOnly(DateTime(2025, 11, 12)),
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
            title: TodoTitle.unsafe('Test Todo 2'),
            completed: false,
            createdAt: DateTime(2025, 11, 13),
            updatedAt: DateTime(2025, 11, 13),
            date: null,
            customListId: null,
            order: 0,
            linkPreview: null,
            recurrence: null,
            parentRecurringId: null,
            eventId: 'event-2',
            needsSync: false,
          ),
        ];

        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => Right(testTodos));

        notifier = createNotifier();

        // Wait for async initialization
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        notifier.state.whenOrNull(
          loaded: (groupedTodos) {
            expect(groupedTodos.length, 2); // 2つの日付グループ
            expect(groupedTodos[DateTime(2025, 11, 12)]?.length, 1);
            expect(groupedTodos[null]?.length, 1);
          },
        );
        
        final isLoaded = notifier.state.maybeMap(
          loaded: (_) => true,
          orElse: () => false,
        );
        expect(isLoaded, true);
      });
    });

    group('createTodo', () {
      test('Todoが正常に作成される', () async {
        // Arrange
        final newTodo = Todo(
          id: 'new-id',
          title: TodoTitle.unsafe('New Todo'),
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
          needsSync: true,
        );

        // 初期化用とcreate後のreload用
        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => const Right([]));
        when(() => mockCreateTodoUseCase(any()))
            .thenAnswer((_) async => Right(newTodo));

        notifier = createNotifier();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.createTodo(title: 'New Todo');

        // Assert
        verify(() => mockCreateTodoUseCase(any())).called(1);
        verify(() => mockGetAllTodosUseCase(const NoParams())).called(2); // 初期化 + reload
      });
    });

    group('toggleTodo', () {
      test('Todoの完了状態がトグルされる', () async {
        // Arrange
        final toggledTodo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('Test Todo'),
          completed: true,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          date: null,
          customListId: null,
          order: 0,
          linkPreview: null,
          recurrence: null,
          parentRecurringId: null,
          eventId: 'event-1',
          needsSync: true,
        );

        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => const Right([]));
        when(() => mockToggleTodoUseCase(any()))
            .thenAnswer((_) async => Right(toggledTodo));

        notifier = createNotifier();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.toggleTodo('test-id');

        // Assert
        verify(() => mockToggleTodoUseCase(any())).called(1);
        verify(() => mockGetAllTodosUseCase(const NoParams())).called(2); // 初期化 + reload
      });
    });

    group('deleteTodo', () {
      test('Todoが正常に削除される', () async {
        // Arrange
        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => const Right([]));
        when(() => mockDeleteTodoUseCase(any()))
            .thenAnswer((_) async => const Right(null));

        notifier = createNotifier();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.deleteTodo('test-id');

        // Assert
        verify(() => mockDeleteTodoUseCase(any())).called(1);
        verify(() => mockGetAllTodosUseCase(const NoParams())).called(2); // 初期化 + reload
      });
    });

    group('syncFromNostr', () {
      test('Nostrから正常に同期される', () async {
        // Arrange
        final syncedTodos = <Todo>[
          Todo(
            id: 'synced-id',
            title: TodoTitle.unsafe('Synced Todo'),
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
        ];

        when(() => mockGetAllTodosUseCase(any()))
            .thenAnswer((_) async => const Right([]));
        when(() => mockSyncFromNostrUseCase(any()))
            .thenAnswer((_) async => Right(syncedTodos));

        notifier = createNotifier();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.syncFromNostr();

        // Assert
        verify(() => mockSyncFromNostrUseCase(const NoParams())).called(1);
        verify(() => mockGetAllTodosUseCase(const NoParams())).called(2); // 初期化 + reload
      });
    });
  });
}

