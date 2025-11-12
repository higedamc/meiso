import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/custom_list.dart' as legacy;
import '../../../../providers/custom_lists_provider.dart' as old;
import '../../domain/entities/custom_list.dart' as domain;
import '../../domain/value_objects/list_name.dart';
import '../view_models/custom_list_view_model.dart';
import 'custom_list_providers.dart';

/// 既存UIとの互換性レイヤー
/// 
/// CustomListStateをAsyncValue<List<CustomList>>に変換し、
/// 既存のcustomListsProviderと同じインターフェースを提供する

// ============================================================================
// 互換Provider（AsyncValue変換）
// ============================================================================

/// 既存のcustomListsProviderと互換性のあるProvider
/// 
/// CustomListState → AsyncValue<List<legacy.CustomList>> に変換
final customListsProviderCompat = Provider<AsyncValue<List<legacy.CustomList>>>((ref) {
  final state = ref.watch(customListViewModelProvider);
  
  return state.maybeMap(
    initial: (_) => const AsyncValue.loading(),
    loading: (_) => const AsyncValue.loading(),
    loaded: (loadedState) {
      // domain.CustomList → legacy.CustomList に変換
      final legacyLists = loadedState.customLists.map((domainList) {
        return _convertDomainToLegacy(domainList);
      }).toList();
      
      return AsyncValue.data(legacyLists);
    },
    error: (errorState) => AsyncValue.error(
      errorState.failure.message,
      StackTrace.current,
    ),
    orElse: () => const AsyncValue.loading(),
  );
});

/// 既存の.notifier アクセス用の互換ラッパー
/// 
/// 使用例: ref.read(customListsProviderNotifierCompat).addList(...)
final customListsProviderNotifierCompat = Provider<CustomListViewModelCompat>((ref) {
  final viewModel = ref.watch(customListViewModelProvider.notifier);
  return CustomListViewModelCompat(viewModel, ref);
});

// ============================================================================
// Domain → Legacy 変換関数
// ============================================================================

/// Domain層のCustomListをLegacy層のCustomListに変換
legacy.CustomList _convertDomainToLegacy(domain.CustomList domainList) {
  return legacy.CustomList(
    id: domainList.id,
    name: domainList.name.value,
    order: domainList.order,
    createdAt: domainList.createdAt,
    updatedAt: domainList.updatedAt,
  );
}

// ============================================================================
// ViewModel互換ラッパー
// ============================================================================

/// CustomListViewModelをラップして互換メソッドを提供
class CustomListViewModelCompat {
  CustomListViewModelCompat(this._viewModel, this._ref);
  
  final CustomListViewModel _viewModel;
  final Ref _ref;
  
  /// 新しいリストを追加（既存メソッド互換）
  Future<void> addList(String name) async {
    // 現在のリスト数を取得してorderを決定
    final currentLists = await _getCurrentLists();
    final nextOrder = currentLists.isEmpty 
        ? 0 
        : currentLists.map((l) => l.order).reduce((a, b) => a > b ? a : b) + 1;
    
    await _viewModel.createCustomList(
      name: name,
      order: nextOrder,
    );
  }
  
  /// リストを更新（既存メソッド互換）
  Future<void> updateList(legacy.CustomList list) async {
    await _viewModel.updateCustomList(
      id: list.id,
      name: list.name,
      order: list.order,
    );
  }
  
  /// リストを削除（既存メソッド互換）
  Future<void> deleteList(String id) async {
    await _viewModel.deleteCustomList(id);
  }
  
  /// リストを並び替え（既存メソッド互換）
  Future<void> reorderLists(int oldIndex, int newIndex) async {
    final currentLists = await _getCurrentLists();
    final reorderedLists = List<legacy.CustomList>.from(currentLists);
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = reorderedLists.removeAt(oldIndex);
    reorderedLists.insert(newIndex, item);
    
    // orderを再計算してDomain層のエンティティに変換
    final domainLists = <domain.CustomList>[];
    for (var i = 0; i < reorderedLists.length; i++) {
      final legacyList = reorderedLists[i];
      final nameResult = ListName.create(legacyList.name);
      
      if (nameResult.isLeft()) {
        continue; // バリデーションエラーはスキップ
      }
      
      final name = nameResult.getOrElse(() => throw Exception('Should never happen'));
      
      domainLists.add(domain.CustomList(
        id: legacyList.id,
        name: name,
        order: i,
        createdAt: legacyList.createdAt,
        updatedAt: DateTime.now(),
      ));
    }
    
    await _viewModel.reorderCustomLists(domainLists);
  }
  
  /// Nostrから同期（既存メソッド互換）
  Future<void> syncListsFromNostr(List<String> nostrListNames) async {
    await _viewModel.syncFromNostr(nostrListNames);
  }
  
  /// デフォルトリストを作成（既存メソッド互換）
  Future<void> createDefaultListsIfEmpty() async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(old.customListsProvider.notifier).createDefaultListsIfEmpty();
  }
  
  /// 現在のリストを取得するヘルパー
  Future<List<legacy.CustomList>> _getCurrentLists() async {
    final asyncValue = _ref.read(customListsProviderCompat);
    return asyncValue.when(
      data: (lists) => lists,
      loading: () => [],
      error: (_, __) => [],
    );
  }
}

