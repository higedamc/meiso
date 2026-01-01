import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../services/logger_service.dart';
import '../../domain/repositories/todo_repository.dart';

/// DeleteTodoUseCaseのパラメータ
class DeleteTodoParams { // 現在のTodoリスト

  const DeleteTodoParams({
    required this.id,
    required this.date,
    required this.currentTodos,
  });
  final String id;
  final DateTime? date;
  final Map<DateTime?, List<Todo>> currentTodos;
}

/// Todoを削除するUseCase
/// 
/// Phase C.1: Repository層統合
/// 
/// 責務:
/// - Todoの存在確認
/// - リストからTodoを削除
/// - ローカルストレージから削除（Repository経由）
/// - 削除後のTodoリストを返す
class DeleteTodoUseCase implements UseCase<Map<DateTime?, List<Todo>>, DeleteTodoParams> {
  
  DeleteTodoUseCase(this._repository);
  final TodoRepository _repository;
  
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

      // Phase C.1: Repository経由でローカルから削除
      AppLogger.debug('🗑️ Deleting todo from local storage via Repository...');
      final deleteResult = await _repository.deleteTodoFromLocal(params.id);
      
      // 削除失敗時はエラーを返す
      if (deleteResult.isLeft()) {
        return deleteResult.fold(
          (failure) {
            AppLogger.error('❌ Failed to delete todo from local: ${failure.message}');
            return Left(failure);
          },
          (_) => Right(updatedTodos), // これは到達しない
        );
      }
      
      AppLogger.info('✅ Todo deleted from local storage');
      return Right(updatedTodos);
    } catch (e, stackTrace) {
      AppLogger.error('❌ DeleteTodoUseCase failed: $e', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Todoの削除に失敗しました: $e'));
    }
  }
}

