import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/todo.dart';
import '../../../../providers/todos_provider.dart' as old;
import 'todo_providers.dart';

/// 旧UIとの互換性レイヤー
/// 
/// 旧todosProviderと同じインターフェース（AsyncValue<Map<DateTime?, List<Todo>>>）を提供

// ============================================================================
// 互換Provider（AsyncValue変換）
// ============================================================================

/// 旧todosProviderと互換性のあるProvider
/// 
/// 新ViewModelのStateをAsyncValue<Map<DateTime?, List<Todo>>>に変換
final todosProviderCompat = Provider<AsyncValue<Map<DateTime?, List<Todo>>>>((ref) {
  final state = ref.watch(todoListViewModelProvider);
  
  return state.when(
    initial: () => const AsyncValue.loading(),
    loading: () => const AsyncValue.loading(),
    loaded: (groupedTodos) => AsyncValue.data(groupedTodos),
    error: (message) => AsyncValue.error(message, StackTrace.current),
  );
});

/// 旧Provider（読み込み専用）
/// 
/// todosProviderCompatが新ViewModelを使うようになったが、
/// 一部の画面では旧Providerの機能が必要なため、
/// 旧Providerも引き続き利用可能にしておく
final todosProvider = old.todosProvider;

