import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../models/todo.dart';

part 'todo_list_state.freezed.dart';

/// TodoリストのState（Freezed Union型）
@freezed
class TodoListState with _$TodoListState {
  const factory TodoListState.initial() = _Initial;
  
  const factory TodoListState.loading() = _Loading;
  
  const factory TodoListState.loaded({
    required Map<DateTime?, List<Todo>> groupedTodos,
  }) = _Loaded;
  
  const factory TodoListState.error({
    required String message,
  }) = _Error;
}

