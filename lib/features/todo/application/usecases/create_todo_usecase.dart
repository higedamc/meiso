import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../../../models/link_preview.dart';
import '../../../../models/recurrence_pattern.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/value_objects/todo_date.dart';
import '../../domain/value_objects/todo_title.dart';

/// Todoを作成するUseCase
class CreateTodoUseCase implements UseCase<Todo, CreateTodoParams> {
  const CreateTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, Todo>> call(CreateTodoParams params) async {
    // TodoTitleのバリデーション
    final titleResult = TodoTitle.create(params.title);
    if (titleResult.isLeft()) {
      return Left(
        titleResult.fold(
          (failure) => failure,
          (_) => throw Exception('Unreachable'),
        ),
      );
    }

    final title = titleResult.getOrElse(() => throw Exception('Unreachable'));

    // Todoエンティティを作成
    final todo = Todo(
      id: '', // 新規作成時は空文字列（Repositoryで生成）
      title: title,
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      date: params.date,
      customListId: params.customListId,
      order: params.order ?? 0,
      linkPreview: params.linkPreview,
      recurrence: params.recurrence,
      parentRecurringId: params.parentRecurringId,
      eventId: null,
      needsSync: true, // 新規作成なので同期が必要
    );

    // Repositoryで作成
    return _repository.createTodo(todo);
  }
}

/// CreateTodoUseCaseのパラメータ
class CreateTodoParams {
  const CreateTodoParams({
    required this.title,
    this.date,
    this.customListId,
    this.order,
    this.linkPreview,
    this.recurrence,
    this.parentRecurringId,
  });

  final String title;
  final TodoDate? date;
  final String? customListId;
  final int? order;
  final LinkPreview? linkPreview;
  final RecurrencePattern? recurrence;
  final String? parentRecurringId;
}

