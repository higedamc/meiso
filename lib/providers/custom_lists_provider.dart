import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_list.dart';
import '../services/local_storage_service.dart';

/// カスタムリストを管理するProvider
final customListsProvider =
    StateNotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>(
  (ref) => CustomListsNotifier(),
);

class CustomListsNotifier extends StateNotifier<AsyncValue<List<CustomList>>> {
  CustomListsNotifier() : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localLists = await localStorageService.loadCustomLists();
      
      if (localLists.isEmpty) {
        // 初回起動時のみダミーデータを作成
        await _createInitialLists();
      } else {
        // order順にソート
        final sortedLists = List<CustomList>.from(localLists)
          ..sort((a, b) => a.order.compareTo(b.order));
        
        state = AsyncValue.data(sortedLists);
      }
    } catch (e) {
      print('⚠️ CustomList初期化エラー: $e');
      state = AsyncValue.data([]);
    }
  }

  /// 初回起動時のダミーデータを作成
  Future<void> _createInitialLists() async {
    final now = DateTime.now();
    
    final initialListNames = [
      'BRAIN DUMP',
      'GROCERY LIST',
      'TO BUY',
      'NOSTR',
      'WORK',
    ];
    
    final initialLists = initialListNames.asMap().entries.map((entry) {
      final index = entry.key;
      final name = entry.value;
      return CustomList(
        id: CustomListHelpers.generateIdFromName(name), // 名前ベースのID
        name: name,
        order: index,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();
    
    // ローカルストレージに保存
    await localStorageService.saveCustomLists(initialLists);
    
    // 状態に反映
    state = AsyncValue.data(initialLists);
  }

  /// 新しいリストを追加
  Future<void> addList(String name) async {
    if (name.trim().isEmpty) return;

    await state.whenData((lists) async {
      final now = DateTime.now();
      final normalizedName = name.trim().toUpperCase();
      
      // リスト名から決定的なIDを生成（NIP-51準拠）
      final listId = CustomListHelpers.generateIdFromName(normalizedName);
      
      // 同じIDのリストが既に存在するかチェック
      if (lists.any((list) => list.id == listId)) {
        print('⚠️ List with ID "$listId" already exists');
        return;
      }
      
      final newList = CustomList(
        id: listId, // UUID v4の代わりに名前ベースのIDを使用
        name: normalizedName,
        order: _getNextOrder(lists),
        createdAt: now,
        updatedAt: now,
      );

      print('✅ Creating new list: "$normalizedName" with ID: "$listId"');

      final updatedLists = [...lists, newList];
      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// リストを更新
  Future<void> updateList(CustomList list) async {
    await state.whenData((lists) async {
      final index = lists.indexWhere((l) => l.id == list.id);
      if (index == -1) return;

      final updatedList = list.copyWith(updatedAt: DateTime.now());
      final updatedLists = [...lists];
      updatedLists[index] = updatedList;

      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// リストを削除
  Future<void> deleteList(String id) async {
    await state.whenData((lists) async {
      final updatedLists = lists.where((l) => l.id != id).toList();
      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// リストを並び替え
  Future<void> reorderLists(int oldIndex, int newIndex) async {
    await state.whenData((lists) async {
      final updatedLists = List<CustomList>.from(lists);

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = updatedLists.removeAt(oldIndex);
      updatedLists.insert(newIndex, item);

      // orderを再計算
      for (var i = 0; i < updatedLists.length; i++) {
        updatedLists[i] = updatedLists[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        );
      }

      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// 次のorder値を取得
  int _getNextOrder(List<CustomList> lists) {
    if (lists.isEmpty) return 0;
    return lists.map((l) => l.order).reduce((a, b) => a > b ? a : b) + 1;
  }
  
  /// Nostrから同期されたカスタムリストを反映
  /// listNameのListを受け取り、ローカルにないリストを追加
  Future<void> syncListsFromNostr(List<String> nostrListNames) async {
    await state.whenData((currentLists) async {
      final updatedLists = List<CustomList>.from(currentLists);
      final now = DateTime.now();
      bool hasChanges = false;
      
      for (final listName in nostrListNames) {
        // 名前から決定的なIDを生成
        final listId = CustomListHelpers.generateIdFromName(listName);
        
        // すでに存在するか確認（IDで）
        final exists = updatedLists.any((list) => list.id == listId);
        
        if (!exists) {
          print('✨ [CustomLists] Adding synced list from Nostr: "$listName" (ID: $listId)');
          
          final newList = CustomList(
            id: listId, // 名前から生成した決定的なID
            name: listName.toUpperCase(),
            order: _getNextOrder(updatedLists),
            createdAt: now,
            updatedAt: now,
          );
          
          updatedLists.add(newList);
          hasChanges = true;
        } else {
          print('ℹ️ [CustomLists] List "$listName" (ID: $listId) already exists, skipping');
        }
      }
      
      if (hasChanges) {
        // order順にソート
        updatedLists.sort((a, b) => a.order.compareTo(b.order));
        
        state = AsyncValue.data(updatedLists);
        
        // ローカルストレージに保存
        await localStorageService.saveCustomLists(updatedLists);
        
        print('✅ [CustomLists] Synced ${nostrListNames.length} lists from Nostr (added ${updatedLists.length - currentLists.length} new)');
      } else {
        print('ℹ️ [CustomLists] No new lists to sync from Nostr');
      }
    }).value;
  }
}

