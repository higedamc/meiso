import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../services/logger_service.dart';
import '../../domain/repositories/todo_repository.dart';

/// UpdateTodoUseCaseのパラメータ
class UpdateTodoParams { // 現在のTodoリスト

  const UpdateTodoParams({
    required this.todo,
    required this.currentTodos,
  });
  final Todo todo;
  final Map<DateTime?, List<Todo>> currentTodos;
}

/// Todoを更新するUseCase
/// 
/// Phase C.1: Repository層統合
/// 
/// 責務:
/// - Todoの存在確認
/// - updatedAtとneedsSyncの更新
/// - ローカルストレージへの永続化（Repository経由）
/// - 更新後のTodoリストを返す
class UpdateTodoUseCase implements UseCase<Map<DateTime?, List<Todo>>, UpdateTodoParams> {
  
  UpdateTodoUseCase(this._repository);
  final TodoRepository _repository;
  
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

      // Phase C.1: Repository経由でローカルに保存
      AppLogger.debug('💾 Saving updated todo to local storage via Repository...');
      final updatedTodo = list[index];
      final saveResult = await _repository.saveTodoToLocal(updatedTodo);
      
      // 保存失敗時はエラーを返す
      if (saveResult.isLeft()) {
        return saveResult.fold(
          (failure) {
            AppLogger.error('❌ Failed to save updated todo to local: ${failure.message}');
            return Left(failure);
          },
          (_) => Right(updatedTodos), // これは到達しない
        );
      }
      
      AppLogger.info('✅ Todo updated and saved to local storage');
      return Right(updatedTodos);
    } catch (e, stackTrace) {
      AppLogger.error('❌ UpdateTodoUseCase failed: $e', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Todoの更新に失敗しました: $e'));
    }
  }
}

