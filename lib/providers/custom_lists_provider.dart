import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/logger_service.dart';
import '../models/custom_list.dart';
import '../services/local_storage_service.dart';
import '../services/group_task_service.dart';
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
        // AppSettingsから保存された順番を適用
        await _applySavedListOrder(localLists);
        
        AppLogger.info(' [CustomLists] Loaded ${localLists.length} lists from local storage');
        state = AsyncValue.data(localLists);
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
      
      // AppSettingsのcustomListOrderも更新
      await _updateCustomListOrderInSettings(initialLists);
      
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
      
      // AppSettingsのcustomListOrderも更新
      await _updateCustomListOrderInSettings(updatedLists);
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
      
      // リスト名が変更された場合、IDも変わる可能性があるため、
      // customListOrderも更新（ただし現在はIDは不変なので、実質影響なし）
      await _updateCustomListOrderInSettings(updatedLists);
    }).value;
  }

  /// リストを削除
  Future<void> deleteList(String id) async {
    await state.whenData((lists) async {
      final updatedLists = lists.where((l) => l.id != id).toList();
      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
      
      // AppSettingsのcustomListOrderも更新（削除されたリストIDを除外）
      await _updateCustomListOrderInSettings(updatedLists);
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
    AppLogger.info(' [CustomLists] 🔄 syncListsFromNostr called with ${nostrListNames.length} lists from Nostr');
    AppLogger.info(' [CustomLists] 📋 Nostr lists: ${nostrListNames.join(", ")}');
    
    final currentState = state;
    AppLogger.debug(' [CustomLists] Current state type: ${currentState.runtimeType}');
    
    // 現在のリストを取得
    List<CustomList> currentLists;
    bool needsStateUpdate = false; // stateの更新が必要かどうか
    
    if (currentState is AsyncData<List<CustomList>>) {
      // 既にデータがロードされている場合
      currentLists = currentState.value;
      AppLogger.debug(' [CustomLists] Using current state (${currentLists.length} lists)');
    } else {
      // AsyncLoadingやAsyncErrorの場合は、ローカルストレージから直接読み込む
      AppLogger.warning(' [CustomLists] State is ${currentState.runtimeType}, loading from local storage');
      currentLists = await localStorageService.loadCustomLists();
      AppLogger.info(' [CustomLists] Loaded ${currentLists.length} lists from local storage');
      needsStateUpdate = true; // AsyncLoadingから読み込んだので、stateの更新が必要
    }
    AppLogger.info(' [CustomLists] 📱 Current local lists: ${currentLists.length}');
    for (final list in currentLists) {
      AppLogger.debug(' [CustomLists]   - "${list.name}" (ID: ${list.id}, isGroup: ${list.isGroup})');
    }
    
    final updatedLists = List<CustomList>.from(currentLists);
    final now = DateTime.now();
    bool hasChanges = false;
    
    for (final listName in nostrListNames) {
      // 名前から決定的なIDを生成
      final listId = CustomListHelpers.generateIdFromName(listName);
      AppLogger.debug(' [CustomLists] Processing Nostr list: "$listName" → ID: "$listId"');
      
      // すでに存在するか確認（IDで）
      final exists = updatedLists.any((list) => list.id == listId);
      
      if (!exists) {
        AppLogger.info(' [CustomLists] ✨ Adding NEW list from Nostr: "$listName" (ID: $listId)');
        
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
        AppLogger.debug(' [CustomLists] ⏭️  List "$listName" (ID: $listId) already exists, skipping');
      }
    }
    
    AppLogger.info(' [CustomLists] 📊 Sync result: hasChanges=$hasChanges, updatedListsCount=${updatedLists.length}, needsStateUpdate=$needsStateUpdate');
    
    // 変更があった場合、または stateの更新が必要な場合
    if (hasChanges || needsStateUpdate) {
      if (hasChanges) {
        AppLogger.info(' [CustomLists] 💾 Saving changes to local storage...');
        
        // AppSettingsから順番を復元
        await _applySavedListOrder(updatedLists);
        
        // ローカルストレージに保存
        await localStorageService.saveCustomLists(updatedLists);
      }
      
      // 状態を更新（UIに確実に通知）
      // hasChangesがfalseでも、AsyncLoadingから読み込んだ場合は更新が必要
      AppLogger.info(' [CustomLists] 🔄 Updating state with ${updatedLists.length} lists...');
      state = AsyncValue.data(updatedLists);
      AppLogger.info(' [CustomLists] ✅ State updated successfully! UI should now reflect ${updatedLists.length} lists');
      
      if (hasChanges) {
        AppLogger.info(' [CustomLists] ✅ Synced ${nostrListNames.length} lists from Nostr (added ${updatedLists.length - currentLists.length} new)');
      }
    } else {
      AppLogger.info(' [CustomLists] ⏭️  No changes needed (all lists already synced and state is up-to-date)');
    }
    
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
  
  // ========================================
  // グループリスト管理機能
  // ========================================
  
  /// グループリストを作成
  /// 
  /// [name]: グループ名
  /// [memberPubkeys]: メンバーの公開鍵リスト（hex形式）
  Future<CustomList?> createGroupList({
    required String name,
    required List<String> memberPubkeys,
  }) async {
    if (name.trim().isEmpty) return null;
    if (memberPubkeys.isEmpty) {
      AppLogger.warning('⚠️ Cannot create group list without members');
      return null;
    }
    
    try {
      final lists = await state.whenData((lists) => lists).value ?? [];
      
      final now = DateTime.now();
      final normalizedName = name.trim().toUpperCase();
      
      // グループIDを生成
      const uuid = Uuid();
      final groupId = uuid.v4();
      
      final newGroupList = CustomList(
        id: groupId,
        name: normalizedName,
        order: _getNextOrder(lists),
        createdAt: now,
        updatedAt: now,
        isGroup: true,
        groupMembers: memberPubkeys,
      );
      
      // ローカルに追加
      final updatedLists = [...lists, newGroupList];
      await localStorageService.saveCustomLists(updatedLists);
      state = AsyncValue.data(updatedLists);
      
      // AppSettingsのcustomListOrderも更新
      await _updateCustomListOrderInSettings(updatedLists);
      
      AppLogger.info('✅ [CustomLists] Created group list: "$normalizedName" with ${memberPubkeys.length} members');
      
      return newGroupList;
    } catch (e, st) {
      AppLogger.error('❌ Failed to create group list: $e', error: e, stackTrace: st);
      return null;
    }
  }
  
  /// グループリストにメンバーを追加
  Future<void> addMemberToGroupList({
    required String groupId,
    required String memberPubkey,
  }) async {
    await state.whenData((lists) async {
      final listIndex = lists.indexWhere((l) => l.id == groupId && l.isGroup);
      if (listIndex == -1) {
        AppLogger.warning('⚠️ Group list not found: $groupId');
        return;
      }
      
      final groupList = lists[listIndex];
      
      // 既にメンバーの場合はスキップ
      if (groupList.groupMembers.contains(memberPubkey)) {
        AppLogger.info('ℹ️ Member already exists in group: $groupId');
        return;
      }
      
      // メンバーを追加
      final updatedMembers = [...groupList.groupMembers, memberPubkey];
      final updatedList = groupList.copyWith(
        groupMembers: updatedMembers,
        updatedAt: DateTime.now(),
      );
      
      final updatedLists = [...lists];
      updatedLists[listIndex] = updatedList;
      
      await localStorageService.saveCustomLists(updatedLists);
      state = AsyncValue.data(updatedLists);
      
      AppLogger.info('✅ Added member to group list: ${groupList.name}');
    }).value;
  }
  
  /// グループリストからメンバーを削除
  Future<void> removeMemberFromGroupList({
    required String groupId,
    required String memberPubkey,
  }) async {
    await state.whenData((lists) async {
      final listIndex = lists.indexWhere((l) => l.id == groupId && l.isGroup);
      if (listIndex == -1) {
        AppLogger.warning('⚠️ Group list not found: $groupId');
        return;
      }
      
      final groupList = lists[listIndex];
      
      // メンバーを削除
      final updatedMembers = groupList.groupMembers
          .where((pubkey) => pubkey != memberPubkey)
          .toList();
      
      if (updatedMembers.isEmpty) {
        AppLogger.warning('⚠️ Cannot remove last member from group');
        return;
      }
      
      final updatedList = groupList.copyWith(
        groupMembers: updatedMembers,
        updatedAt: DateTime.now(),
      );
      
      final updatedLists = [...lists];
      updatedLists[listIndex] = updatedList;
      
      await localStorageService.saveCustomLists(updatedLists);
      state = AsyncValue.data(updatedLists);
      
      AppLogger.info('✅ Removed member from group list: ${groupList.name}');
    }).value;
  }
  
  /// Nostrからグループリストを同期
  Future<void> syncGroupListsFromNostr() async {
    try {
      AppLogger.info('🔄 Syncing group lists from Nostr...');
      
      // Nostrからグループリストを取得
      final groupLists = await groupTaskService.syncGroupLists();
      
      if (groupLists.isEmpty) {
        AppLogger.info('ℹ️ No group lists found on Nostr');
        return;
      }
      
      final currentState = state;
      
      // 現在のリストを取得
      List<CustomList> currentLists;
      bool needsStateUpdate = false; // stateの更新が必要かどうか
      
      if (currentState is AsyncData<List<CustomList>>) {
        // 既にデータがロードされている場合
        currentLists = currentState.value;
        AppLogger.debug(' [CustomLists] Using current state for group sync');
      } else {
        // AsyncLoadingやAsyncErrorの場合は、ローカルストレージから直接読み込む
        AppLogger.warning(' [CustomLists] State is ${currentState.runtimeType} for group sync, loading from local storage');
        currentLists = await localStorageService.loadCustomLists();
        AppLogger.info(' [CustomLists] Loaded ${currentLists.length} lists from local storage for group sync');
        needsStateUpdate = true; // AsyncLoadingから読み込んだので、stateの更新が必要
      }
      final updatedLists = List<CustomList>.from(currentLists);
      bool hasChanges = false;
      
      for (final groupList in groupLists) {
        // 既に存在するか確認（IDで）
        final existingIndex = updatedLists.indexWhere((l) => l.id == groupList.id);
        
        if (existingIndex == -1) {
          // 新しいグループリストを追加
          AppLogger.debug('📥 Adding synced group list: "${groupList.name}"');
          updatedLists.add(groupList);
          hasChanges = true;
        } else {
          // 既存のグループリストを更新（メンバーが変更されている可能性）
          final existing = updatedLists[existingIndex];
          if (existing.groupMembers.length != groupList.groupMembers.length ||
              !existing.groupMembers.every((m) => groupList.groupMembers.contains(m))) {
            AppLogger.debug('🔄 Updating group list members: "${groupList.name}"');
            updatedLists[existingIndex] = groupList.copyWith(
              order: existing.order, // 既存の順番を維持
            );
            hasChanges = true;
          }
        }
      }
      
      // 変更があった場合、または stateの更新が必要な場合
      if (hasChanges || needsStateUpdate) {
        if (hasChanges) {
          // ローカルストレージに保存
          await localStorageService.saveCustomLists(updatedLists);
          
          // AppSettingsのcustomListOrderも更新
          await _updateCustomListOrderInSettings(updatedLists);
        }
        
        // 状態を更新（UIに確実に通知）
        // hasChangesがfalseでも、AsyncLoadingから読み込んだ場合は更新が必要
        state = AsyncValue.data(updatedLists);
        
        AppLogger.info('✅ Synced ${groupLists.length} group lists from Nostr');
        AppLogger.info('📱 State updated successfully! UI should now reflect ${updatedLists.length} total lists');
      }
    } catch (e, st) {
      AppLogger.error('❌ Failed to sync group lists from Nostr: $e', error: e, stackTrace: st);
    }
  }
}

