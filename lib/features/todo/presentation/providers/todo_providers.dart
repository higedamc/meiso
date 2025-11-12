import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/todo_list_view_model.dart';
import '../view_models/todo_list_state.dart';

/// TodoリストViewModel Provider
final todoListViewModelProvider =
    StateNotifierProvider<TodoListViewModel, TodoListState>((ref) {
  return TodoListViewModel(ref);
});

