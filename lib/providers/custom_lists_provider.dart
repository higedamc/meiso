import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import '../models/custom_list.dart';
import '../services/local_storage_service.dart';
import 'app_settings_provider.dart';

/// カスタムリストを管理するProvider
final customListsProvider =
    StateNotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>(
  (ref) => CustomListsNotifier(ref),
);

class CustomListsNotifier extends StateNotifier<AsyncValue<List<CustomList>>> {
  CustomListsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }
  
  final Ref _ref;

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localLists = await localStorageService.loadCustomLists();
      
      if (localLists.isEmpty) {
        // ローカルにリストがない場合は、まず空の状態にする
        // Nostrからの同期を待ってから、必要に応じてデフォルトリストを作成
        AppLogger.info(' [CustomLists] No local lists found. Waiting for Nostr sync...');
        state = AsyncValue.data([]);
      } else {
        // order順にソート
        final sortedLists = List<CustomList>.from(localLists)
          ..sort((a, b) => a.order.compareTo(b.order));
        
        AppLogger.info(' [CustomLists] Loaded ${sortedLists.length} lists from local storage');
        state = AsyncValue.data(sortedLists);
      }
    } catch (e) {
      AppLogger.warning(' CustomList初期化エラー: $e');
      state = AsyncValue.data([]);
    }
  }

  /// 初回起動時のデフォルトリストを作成（Nostr同期後にリストが空の場合のみ）
  Future<void> createDefaultListsIfEmpty() async {
    await state.whenData((lists) async {
      // 既にリストがある場合は何もしない
      if (lists.isNotEmpty) {
        AppLogger.debug(' [CustomLists] Lists already exist, skipping default creation');
        return;
      }
      
      AppLogger.info(' [CustomLists] Creating default lists (no lists found after Nostr sync)');
      
      final now = DateTime.now();
      
      final initialListNames = [
        'BRAIN DUMP',
        'GROCERY',
        'WISHLIST',
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
      
      AppLogger.info(' [CustomLists] Created ${initialLists.length} default lists');
    }).value;
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
        AppLogger.warning(' List with ID "$listId" already exists');
        return;
      }
      
      final newList = CustomList(
        id: listId, // UUID v4の代わりに名前ベースのIDを使用
        name: normalizedName,
        order: _getNextOrder(lists),
        createdAt: now,
        updatedAt: now,
      );

      AppLogger.info(' Creating new list: "$normalizedName" with ID: "$listId"');

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
      
      // AppSettingsのcustomListOrderも更新
      await _updateCustomListOrderInSettings(updatedLists);
    }).value;
  }
  
  /// AppSettingsのcustomListOrderを更新
  Future<void> _updateCustomListOrderInSettings(List<CustomList> lists) async {
    try {
      final listOrder = lists.map((list) => list.id).toList();
      final settingsAsync = _ref.read(appSettingsProvider);
      
      await settingsAsync.whenData((currentSettings) async {
        final updatedSettings = currentSettings.copyWith(
          customListOrder: listOrder,
          updatedAt: DateTime.now(),
        );
        
        await _ref.read(appSettingsProvider.notifier).updateSettings(updatedSettings);
        AppLogger.info(' [CustomLists] リスト順をAppSettingsに同期しました');
      }).value;
    } catch (e) {
      AppLogger.warning(' [CustomLists] AppSettings更新エラー: $e');
    }
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
          AppLogger.debug(' [CustomLists] Adding synced list from Nostr: "$listName" (ID: $listId)');
          
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
          AppLogger.debug(' [CustomLists] List "$listName" (ID: $listId) already exists, skipping');
        }
      }
      
      if (hasChanges) {
        // AppSettingsから順番を復元
        await _applySavedListOrder(updatedLists);
        
        state = AsyncValue.data(updatedLists);
        
        // ローカルストレージに保存
        await localStorageService.saveCustomLists(updatedLists);
        
        AppLogger.info(' [CustomLists] Synced ${nostrListNames.length} lists from Nostr (added ${updatedLists.length - currentLists.length} new)');
      } else {
        AppLogger.debug(' [CustomLists] No new lists to sync from Nostr');
      }
    }).value;
    
    // Nostr同期後、リストが空の場合はデフォルトリストを作成
    await createDefaultListsIfEmpty();
  }
  
  /// AppSettingsから保存された順番を適用
  Future<void> _applySavedListOrder(List<CustomList> lists) async {
    try {
      final settingsAsync = _ref.read(appSettingsProvider);
      
      await settingsAsync.whenData((settings) async {
        final savedOrder = settings.customListOrder;
        
        if (savedOrder.isEmpty) {
          // 保存された順番がない場合は、現在のorder順にソート
          lists.sort((a, b) => a.order.compareTo(b.order));
          AppLogger.debug(' [CustomLists] 保存された順番なし。現在のorder順を使用');
          return;
        }
        
        AppLogger.info(' [CustomLists] AppSettingsから順番を復元: ${savedOrder.length}件');
        
        // 保存された順番に従って並び替え
        final Map<String, CustomList> listMap = {for (var list in lists) list.id: list};
        final reorderedLists = <CustomList>[];
        
        // 保存された順番に従ってリストを追加
        for (final listId in savedOrder) {
          if (listMap.containsKey(listId)) {
            reorderedLists.add(listMap[listId]!);
            listMap.remove(listId);
          }
        }
        
        // 保存された順番にないリストを末尾に追加
        reorderedLists.addAll(listMap.values);
        
        // orderを再計算
        for (var i = 0; i < reorderedLists.length; i++) {
          reorderedLists[i] = reorderedLists[i].copyWith(order: i);
        }
        
        lists.clear();
        lists.addAll(reorderedLists);
        
        AppLogger.info(' [CustomLists] リスト順を復元しました');
      }).value;
    } catch (e) {
      AppLogger.warning(' [CustomLists] 順番復元エラー: $e');
      // エラー時は現在のorder順にソート
      lists.sort((a, b) => a.order.compareTo(b.order));
    }
  }
}

