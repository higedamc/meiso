import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/providers/repository_providers.dart';
import '../usecases/create_todo_usecase.dart';
import '../usecases/delete_todo_usecase.dart';
import '../usecases/generate_recurring_instances_usecase.dart';
import '../usecases/remove_child_instances_usecase.dart';
import '../usecases/update_todo_usecase.dart';

/// CreateTodoUseCaseのProvider
/// 
/// Phase C.1: Repository層を注入
final createTodoUseCaseProvider = Provider<CreateTodoUseCase>((ref) {
  return CreateTodoUseCase();
});

/// UpdateTodoUseCaseのProvider
/// 
/// Phase C.1: Repository層を注入
final updateTodoUseCaseProvider = Provider<UpdateTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return UpdateTodoUseCase(repository);
});

/// DeleteTodoUseCaseのProvider
/// 
/// Phase C.1: Repository層を注入
final deleteTodoUseCaseProvider = Provider<DeleteTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return DeleteTodoUseCase(repository);
});

/// GenerateRecurringInstancesUseCaseのProvider
/// 
/// Phase C.2.3: リカーリングタスクの将来インスタンス生成（14日ローリングウィンドウ）
final generateRecurringInstancesUseCaseProvider = Provider<GenerateRecurringInstancesUseCase>((ref) {
  return GenerateRecurringInstancesUseCase();
});

/// RemoveChildInstancesUseCaseのProvider
/// 
/// Phase C.2.3: リカーリングタスクの子インスタンス削除
final removeChildInstancesUseCaseProvider = Provider<RemoveChildInstancesUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return RemoveChildInstancesUseCase(repository);
});
