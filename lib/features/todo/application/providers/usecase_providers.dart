import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../usecases/create_todo_usecase.dart';
import '../usecases/update_todo_usecase.dart';
import '../usecases/delete_todo_usecase.dart';

/// CreateTodoUseCaseのProvider
final createTodoUseCaseProvider = Provider<CreateTodoUseCase>((ref) {
  return CreateTodoUseCase();
});

/// UpdateTodoUseCaseのProvider
final updateTodoUseCaseProvider = Provider<UpdateTodoUseCase>((ref) {
  return UpdateTodoUseCase();
});

/// DeleteTodoUseCaseのProvider
final deleteTodoUseCaseProvider = Provider<DeleteTodoUseCase>((ref) {
  return DeleteTodoUseCase();
});

