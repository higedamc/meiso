import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/custom_list.dart';
import '../../../../providers/custom_lists_provider.dart' as old;
import 'custom_list_providers.dart';

/// 旧UIとの互換性レイヤー
/// 
/// 旧customListsProviderと同じインターフェース（AsyncValue<List<CustomList>>）を提供

// ============================================================================
// 互換Provider（AsyncValue変換）
// ============================================================================

/// 旧customListsProviderと互換性のあるProvider
/// 
/// 新ViewModelのStateをAsyncValue<List<CustomList>>に変換
final customListsProviderCompat = Provider<AsyncValue<List<CustomList>>>((ref) {
  final state = ref.watch(customListViewModelProvider);
  
  return state.when(
    initial: () => const AsyncValue.loading(),
    loading: () => const AsyncValue.loading(),
    loaded: (customLists) => AsyncValue.data(customLists),
    error: (message) => AsyncValue.error(message, StackTrace.current),
  );
});

/// 旧Provider（読み込み専用）
/// 
/// customListsProviderCompatが新ViewModelを使うようになったが、
/// 一部の画面では旧Providerの機能が必要なため、
/// 旧Providerも引き続き利用可能にしておく
final customListsProvider = old.customListsProvider;

