import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../services/logger_service.dart';

/// DeleteTodoUseCaseのパラメータ
class DeleteTodoParams {
  final String id;
  final DateTime? date;
  final Map<DateTime?, List<Todo>> currentTodos; // 現在のTodoリスト

  const DeleteTodoParams({
    required this.id,
    required this.date,
    required this.currentTodos,
  });
}

/// Todoを削除するUseCase
/// 
/// 責務:
/// - Todoの存在確認
/// - リストからTodoを削除
/// - 削除後のTodoリストを返す
/// 
/// 注意:
/// - ローカルストレージ保存やNostr同期は行わない（Provider層の責務）
/// - Phase CでRepository層導入時に、これらの処理も移動予定
class DeleteTodoUseCase implements UseCase<Map<DateTime?, List<Todo>>, DeleteTodoParams> {
  @override
  Future<Either<Failure, Map<DateTime?, List<Todo>>>> call(DeleteTodoParams params) async {
    try {
      AppLogger.info('🔧 DeleteTodoUseCase: Deleting todo ${params.id}');

      // 対象の日付のTodoリストを取得
      final list = List<Todo>.from(params.currentTodos[params.date] ?? []);
      
      // Todoが存在するか確認
      final exists = list.any((t) => t.id == params.id);
      if (!exists) {
        AppLogger.warning('⚠️ Todo not found: ${params.id}');
        return const Left(ValidationFailure('削除対象のTodoが見つかりません'));
      }

      // Todoを削除
      list.removeWhere((t) => t.id == params.id);

      // 削除後のTodoマップを作成
      final updatedTodos = {
        ...params.currentTodos,
        params.date: list,
      };

      AppLogger.info('✅ Todo deleted successfully');
      return Right(updatedTodos);
    } catch (e, stackTrace) {
      AppLogger.error('❌ DeleteTodoUseCase failed: $e', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Todoの削除に失敗しました: $e'));
    }
  }
}

