import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/todo.dart';
import '../../../../core/common/failure.dart';

part 'todo_list_state.freezed.dart';

/// TodoリストのStateを表現するクラス
@freezed
class TodoListState with _$TodoListState {
  const factory TodoListState.initial() = _Initial;
  const factory TodoListState.loading() = _Loading;
  const factory TodoListState.loaded({
    required Map<DateTime?, List<Todo>> groupedTodos,
  }) = _Loaded;
  const factory TodoListState.error(Failure failure) = _Error;
}

