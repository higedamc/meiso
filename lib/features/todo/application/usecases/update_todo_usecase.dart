import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../../../models/link_preview.dart';
import '../../../../models/recurrence_pattern.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/value_objects/todo_date.dart';
import '../../domain/value_objects/todo_title.dart';

/// Todoを更新するUseCase
class UpdateTodoUseCase implements UseCase<Todo, UpdateTodoParams> {
  const UpdateTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, Todo>> call(UpdateTodoParams params) async {
    // 既存のTodoを取得
    final todoResult = await _repository.getTodoById(params.todoId);
    if (todoResult.isLeft()) {
      return todoResult;
    }

    final existingTodo = todoResult.getOrElse(() => throw Exception('Unreachable'));

    // タイトルが更新される場合、バリデーション
    TodoTitle? newTitle;
    if (params.title != null) {
      final titleResult = TodoTitle.create(params.title!);
      if (titleResult.isLeft()) {
        return Left(
          titleResult.fold(
            (failure) => failure,
            (_) => throw Exception('Unreachable'),
          ),
        );
      }
      newTitle = titleResult.getOrElse(() => throw Exception('Unreachable'));
    }

    // 更新されたTodoを作成
    final updatedTodo = existingTodo.copyWith(
      title: newTitle ?? existingTodo.title,
      completed: params.completed ?? existingTodo.completed,
      date: params.date ?? existingTodo.date,
      customListId: params.customListId ?? existingTodo.customListId,
      order: params.order ?? existingTodo.order,
      linkPreview: params.linkPreview ?? existingTodo.linkPreview,
      recurrence: params.recurrence ?? existingTodo.recurrence,
      updatedAt: DateTime.now(),
      needsSync: true, // 更新したので同期が必要
    );

    return _repository.updateTodo(updatedTodo);
  }
}

/// UpdateTodoUseCaseのパラメータ
class UpdateTodoParams {
  const UpdateTodoParams({
    required this.todoId,
    this.title,
    this.completed,
    this.date,
    this.customListId,
    this.order,
    this.linkPreview,
    this.recurrence,
  });

  final String todoId;
  final String? title;
  final bool? completed;
  final TodoDate? date;
  final String? customListId;
  final int? order;
  final LinkPreview? linkPreview;
  final RecurrencePattern? recurrence;
}

