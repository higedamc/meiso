import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../usecases/create_todo_usecase.dart';
import '../usecases/update_todo_usecase.dart';
import '../usecases/delete_todo_usecase.dart';
import '../../infrastructure/providers/repository_providers.dart';

/// CreateTodoUseCaseのProvider
/// 
/// Phase C.1: Repository層を注入
final createTodoUseCaseProvider = Provider<CreateTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return CreateTodoUseCase(repository);
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

