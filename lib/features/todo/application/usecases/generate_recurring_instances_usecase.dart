import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../services/logger_service.dart';
import '../../../../models/todo.dart'; // Models層のTodoを使用
import '../../../../models/recurrence_pattern.dart'; // RecurrencePattern拡張のため
import '../../domain/repositories/todo_repository.dart';

/// リカーリングタスクの将来インスタンスを生成するUseCase
/// 
/// 親タスクの繰り返しパターンに基づいて、30日以内の将来のインスタンスを自動生成します。
class GenerateRecurringInstancesUseCase
    implements UseCase<Map<DateTime?, List<Todo>>, GenerateRecurringInstancesParams> {
  final TodoRepository _repository;
  final _uuid = const Uuid();

  GenerateRecurringInstancesUseCase(this._repository);

  @override
  Future<Either<Failure, Map<DateTime?, List<Todo>>>> call(
    GenerateRecurringInstancesParams params,
  ) async {
    try {
      final originalTodo = params.parentTodo;
      final todos = Map<DateTime?, List<Todo>>.from(params.currentTodos);

      // 繰り返しパターンまたは日付がない場合はスキップ
      if (originalTodo.recurrence == null || originalTodo.date == null) {
        AppLogger.debug('[GenerateRecurringInstances] ⏭️ 繰り返しパターンまたは日付がないためスキップ');
        return Right(todos);
      }

      AppLogger.info('[GenerateRecurringInstances] 将来のインスタンスを生成開始: ${originalTodo.title}');
      AppLogger.debug('[GenerateRecurringInstances] 元のタスクの日付: ${originalTodo.date}');

      // 元のタスクが含まれているか確認
      final originalDateTasks = todos[originalTodo.date] ?? [];
      final originalTaskExists = originalDateTasks.any((t) => t.id == originalTodo.id);
      AppLogger.debug('[GenerateRecurringInstances] 元のタスクが存在: $originalTaskExists (${originalDateTasks.length}件のタスク)');

      DateTime? currentDate = originalTodo.date;
      int generatedCount = 0;
      const maxInstances = 50; // 最大50個まで生成（無限ループ防止）
      final now = DateTime.now();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      // 30日以内の将来のインスタンスを生成
      while (generatedCount < maxInstances) {
        final nextDate = originalTodo.recurrence!.calculateNextDate(currentDate!);

        if (nextDate == null) {
          AppLogger.info('[GenerateRecurringInstances] 繰り返し終了');
          break; // 繰り返し終了
        }

        // 30日以内の日付のみ生成
        if (nextDate.isAfter(thirtyDaysLater)) {
          AppLogger.debug('[GenerateRecurringInstances] 30日以内の範囲を超えたため終了');
          break;
        }

        // 既に同じタイトルのタスクが存在するかチェック
        final existingTasks = todos[nextDate] ?? [];
        final alreadyExists = existingTasks.any((t) =>
            t.parentRecurringId == originalTodo.id ||
            (t.title == originalTodo.title && t.recurrence != null && t.id != originalTodo.id));

        if (!alreadyExists) {
          // 新しいインスタンスを生成
          final newTodo = Todo(
            id: _uuid.v4(),
            title: originalTodo.title,
            completed: false,
            date: nextDate,
            order: _getNextOrder(todos, nextDate),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            recurrence: originalTodo.recurrence,
            parentRecurringId: originalTodo.id,
            linkPreview: originalTodo.linkPreview,
            needsSync: true, // 同期が必要
            customListId: originalTodo.customListId, // カスタムリストIDを継承
          );

          final list = List<Todo>.from(todos[nextDate] ?? []);
          list.add(newTodo);
          todos[nextDate] = list;

          generatedCount++;
          AppLogger.info('[GenerateRecurringInstances] インスタンス生成: ${nextDate.month}/${nextDate.day}');
        }

        currentDate = nextDate;
      }

      AppLogger.debug('[GenerateRecurringInstances] 合計${generatedCount}個のインスタンスを生成しました');

      // 最終的に元のタスクが含まれているか確認
      final finalTasks = todos[originalTodo.date] ?? [];
      final finalTaskExists = finalTasks.any((t) => t.id == originalTodo.id);
      AppLogger.debug('[GenerateRecurringInstances] 最終的な元のタスク存在: $finalTaskExists (${finalTasks.length}件のタスク)');

      return Right(todos);
    } catch (e, stackTrace) {
      AppLogger.error('[GenerateRecurringInstances] ❌ Failed to generate recurring instances', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to generate recurring instances: $e'));
    }
  }

  /// 指定された日付の次のorder値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) {
      return 0;
    }
    return list.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// GenerateRecurringInstancesUseCaseのパラメータ
class GenerateRecurringInstancesParams {
  /// 親タスク（繰り返しパターンを持つオリジナルのタスク）
  final Todo parentTodo;

  /// 現在の全Todoマップ
  final Map<DateTime?, List<Todo>> currentTodos;

  const GenerateRecurringInstancesParams({
    required this.parentTodo,
    required this.currentTodos,
  });
}

