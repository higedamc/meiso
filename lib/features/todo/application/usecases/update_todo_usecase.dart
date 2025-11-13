import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../services/logger_service.dart';

/// UpdateTodoUseCaseのパラメータ
class UpdateTodoParams {
  final Todo todo;
  final Map<DateTime?, List<Todo>> currentTodos; // 現在のTodoリスト

  const UpdateTodoParams({
    required this.todo,
    required this.currentTodos,
  });
}

/// Todoを更新するUseCase
/// 
/// 責務:
/// - Todoの存在確認
/// - updatedAtとneedsSyncの更新
/// - 更新後のTodoリストを返す
/// 
/// 注意:
/// - ローカルストレージ保存やNostr同期は行わない（Provider層の責務）
/// - Phase CでRepository層導入時に、これらの処理も移動予定
class UpdateTodoUseCase implements UseCase<Map<DateTime?, List<Todo>>, UpdateTodoParams> {
  @override
  Future<Either<Failure, Map<DateTime?, List<Todo>>>> call(UpdateTodoParams params) async {
    try {
      AppLogger.info('🔧 UpdateTodoUseCase: Updating todo ${params.todo.id}');

      // 対象の日付のTodoリストを取得
      final list = List<Todo>.from(params.currentTodos[params.todo.date] ?? []);
      final index = list.indexWhere((t) => t.id == params.todo.id);

      if (index == -1) {
        AppLogger.warning('⚠️ Todo not found: ${params.todo.id}');
        return const Left(ValidationFailure('更新対象のTodoが見つかりません'));
      }

      // Todoを更新（updatedAtとneedsSyncを自動設定）
      list[index] = params.todo.copyWith(
        updatedAt: DateTime.now(),
        needsSync: true, // 同期が必要
      );

      // 更新後のTodoマップを作成
      final updatedTodos = {
        ...params.currentTodos,
        params.todo.date: list,
      };

      AppLogger.info('✅ Todo updated successfully');
      return Right(updatedTodos);
    } catch (e, stackTrace) {
      AppLogger.error('❌ UpdateTodoUseCase failed: $e', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Todoの更新に失敗しました: $e'));
    }
  }
}

