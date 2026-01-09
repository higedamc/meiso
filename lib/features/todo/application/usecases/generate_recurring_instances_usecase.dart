import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../services/logger_service.dart';
import '../../../../models/todo.dart'; // Models層のTodoを使用
import '../../../../models/recurrence_pattern.dart'; // RecurrencePattern拡張のため

/// リカーリングタスクの将来インスタンスを生成するUseCase
/// 
/// 親タスクの繰り返しパターンに基づいて、14日以内の将来のインスタンスを自動生成します。
/// ローリングウィンドウ方式で、常に「今日 + 13日先まで」をカバーします。
class GenerateRecurringInstancesUseCase
    implements UseCase<Map<DateTime?, List<Todo>>, GenerateRecurringInstancesParams> {

  GenerateRecurringInstancesUseCase();
  final _uuid = const Uuid();

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

      var generatedCount = 0;
      const maxInstances = 30; // 最大30個まで生成（無限ループ防止、14日分で十分）
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // 既存のインスタンスの最大日付を見つける（今日以降のみ）
      DateTime? maxExistingDate;
      for (final dateGroup in todos.values) {
        for (final task in dateGroup) {
          if ((task.parentRecurringId == originalTodo.id || task.id == originalTodo.id) &&
              task.date != null) {
            final taskDate = DateTime(task.date!.year, task.date!.month, task.date!.day);
            // 今日以降のインスタンスのみを対象
            if (!taskDate.isBefore(today)) {
              if (maxExistingDate == null || taskDate.isAfter(maxExistingDate)) {
                maxExistingDate = taskDate;
              }
            }
          }
        }
      }
      
      // 開始日を決定：既存の最大日付、または今日、または元のタスクの日付
      DateTime currentDate = maxExistingDate != null 
          ? maxExistingDate
          : (originalTodo.date!.isBefore(today) 
              ? today.subtract(Duration(days: originalTodo.recurrence!.interval))
              : originalTodo.date!);
      
      // 終了日：開始日から14日後
      final fourteenDaysLater = currentDate.add(const Duration(days: 14));
      
      AppLogger.debug('[GenerateRecurringInstances] 既存の最大日付（今日以降）: $maxExistingDate');
      AppLogger.debug('[GenerateRecurringInstances] 生成開始日: $currentDate');
      AppLogger.debug('[GenerateRecurringInstances] 生成終了日: $fourteenDaysLater');

      // 14日以内の将来のインスタンスを生成（ローリングウィンドウ方式）
      while (generatedCount < maxInstances) {
        final nextDate = originalTodo.recurrence!.calculateNextDate(currentDate);

        if (nextDate == null) {
          AppLogger.info('[GenerateRecurringInstances] 繰り返し終了');
          break; // 繰り返し終了
        }

        AppLogger.debug('[GenerateRecurringInstances] 次の日付候補: $nextDate');

        // 14日以内の日付のみ生成
        if (nextDate.isAfter(fourteenDaysLater)) {
          AppLogger.debug('[GenerateRecurringInstances] 14日以内の範囲を超えたため終了 ($nextDate > $fourteenDaysLater)');
          break;
        }
        
        // 今日より前の日付はスキップ
        if (nextDate.isBefore(today)) {
          AppLogger.debug('[GenerateRecurringInstances] 過去の日付をスキップ: $nextDate');
          currentDate = nextDate;
          continue;
        }

        // 既に同じ親タスクのインスタンスが存在するかチェック
        final existingTasks = todos[nextDate] ?? [];
        final alreadyExists = existingTasks.any((t) =>
            t.parentRecurringId == originalTodo.id ||
            (t.id == originalTodo.id && t.date == nextDate));  // 親タスク自身が同じ日付にいる場合
        
        AppLogger.debug('[GenerateRecurringInstances] $nextDate: 既存=${alreadyExists} (既存タスク${existingTasks.length}件)');

        if (!alreadyExists) {
          // 新しいインスタンスを生成
          final newTodo = Todo(
            id: _uuid.v4(),
            title: originalTodo.title,
            date: nextDate,
            order: _getNextOrder(todos, nextDate),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            recurrence: originalTodo.recurrence,
            parentRecurringId: originalTodo.id,
            linkPreview: originalTodo.linkPreview,
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

      AppLogger.debug('[GenerateRecurringInstances] 合計$generatedCount個のインスタンスを生成しました');

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

  const GenerateRecurringInstancesParams({
    required this.parentTodo,
    required this.currentTodos,
  });
  /// 親タスク（繰り返しパターンを持つオリジナルのタスク）
  final Todo parentTodo;

  /// 現在の全Todoマップ
  final Map<DateTime?, List<Todo>> currentTodos;
}

