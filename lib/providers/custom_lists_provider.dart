import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/logger_service.dart';
import '../models/custom_list.dart';
// Phase 8.4: group_task_service.dart は kind: 30001廃止により未使用
import 'app_settings_provider.dart';
import 'nostr_provider.dart';
import '../services/local_storage_service.dart';
import '../utils/error_handler.dart';
// Phase C.3.1: Repository層統合
import '../features/custom_list/infrastructure/providers/repository_providers.dart';
// Phase E.6: Custom List UseCase統合
import '../features/custom_list/application/providers/usecase_providers.dart';
import '../features/custom_list/application/usecases/delete_personal_list_usecase.dart';
// Phase D.5: MLS UseCase統合
import '../features/mls/application/providers/usecase_providers.dart' as mls_usecase;
import '../features/mls/application/usecases/create_mls_group_usecase.dart';
import '../features/mls/application/usecases/send_group_invitation_usecase.dart';
import '../features/mls/application/usecases/sync_group_invitations_usecase.dart';
// Rust FFI
import '../bridge_generated.dart/api.dart' as rust_api;

/// カスタムリストを管理するProvider
final customListsProvider =
    StateNotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>(
  (ref) => CustomListsNotifier(ref),
);

class CustomListsNotifier extends StateNotifier<AsyncValue<List<CustomList>>> {
  CustomListsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initialize();
    _startInvitationSyncTimer();
  }
  
  final Ref _ref;
  
  /// Phase C.3.1: Repository経由でローカルCRUD操作
  /// MLS機能はProvider内に保持（Phase Dで移行予定）
  late final _repository = _ref.read(customListRepositoryProvider);
  Timer? _invitationSyncTimer;
  
  /// Issue #80: 削除済みイベントIDのセット（kind 5で削除されたリスト）
  Set<String> _deletedEventIds = {};

  Future<void> _initialize() async {
    try {
      // Issue #80: Phase C.3.2.1 - Repository経由で削除済みイベントIDを読み込み
      final deletedIdsResult = await _repository.loadDeletedEventIds();
      deletedIdsResult.fold(
        (failure) {
          AppLogger.warning('🗑️ [CustomLists] Failed to load deleted event IDs: ${failure.message}');
          _deletedEventIds = {};
        },
        (deletedIds) {
          _deletedEventIds = deletedIds;
          AppLogger.info('🗑️ [CustomLists] Loaded ${_deletedEventIds.length} deleted event IDs');
        },
      );
      
      // Phase C.3.1: Repository経由でローカルストレージから読み込み
      final listsResult = await _repository.loadCustomListsFromLocal();
      
      listsResult.fold(
        (failure) {
          AppLogger.warning(' [CustomLists] Failed to load lists: ${failure.message}');
          state = AsyncValue.data([]);
        },
        (localLists) async {
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
        },
      );
      
      // Phase 6.4: 起動時にグループ招待を同期
      // Note: Nostr初期化後に実行されるため、ここでは呼び出しのみ
      Future.microtask(() async {
        try {
          await syncGroupInvitations();
        } catch (e) {
          AppLogger.warning('📥 [GroupInvitations] Initial sync failed: $e');
        }
      });
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
      
      // Phase C.3.1: Repository経由でローカルストレージに保存
      final result = await _repository.saveCustomListsToLocal(initialLists);
      
      result.fold(
        (failure) {
          AppLogger.warning(' [CustomLists] Failed to save default lists: ${failure.message}');
        },
        (_) {
          // 状態に反映
          state = AsyncValue.data(initialLists);
          
          // AppSettingsのcustomListOrderも更新
          _updateCustomListOrderInSettings(initialLists);
          
          AppLogger.info(' [CustomLists] Created ${initialLists.length} default lists');
        },
      );
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

      // Phase C.3.1: Repository経由でローカルストレージに保存
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      result.fold(
        (failure) => AppLogger.warning(' Failed to save list: ${failure.message}'),
        (_) {
          // AppSettingsのcustomListOrderも更新
          _updateCustomListOrderInSettings(updatedLists);
        },
      );
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

      // Phase C.3.1: Repository経由でローカルストレージに保存
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      result.fold(
        (failure) => AppLogger.warning(' Failed to update list: ${failure.message}'),
        (_) {
          // リスト名が変更された場合、IDも変わる可能性があるため、
          // customListOrderも更新（ただし現在はIDは不変なので、実質影響なし）
          _updateCustomListOrderInSettings(updatedLists);
        },
      );
    }).value;
  }

  /// リストを削除
  /// 
  /// Phase E.3: Personal Listの場合、Nostr削除も実行（楽観的UI更新）
  /// 
  /// 動作:
  /// 1. 即座にローカル削除 → UI更新
  /// 2. Personal Listの場合、バックグラウンドでNostr削除（Kind 5）
  /// 3. エラー時はロールバック
  Future<void> deleteList(String id) async {
    await state.whenData((lists) async {
      // 削除対象リストを取得
      final targetList = lists.firstWhere(
        (l) => l.id == id,
        orElse: () => throw Exception('List not found: $id'),
      );
      
      // 1. 楽観的UI更新: 即座にローカルから削除
      final updatedLists = lists.where((l) => l.id != id).toList();
      state = AsyncValue.data(updatedLists);
      
      AppLogger.info(' [CustomLists] Deleting list locally: ${targetList.name} (id: $id)');

      // Phase C.3.1: Repository経由でローカルストレージに保存
      final localResult = await _repository.deleteCustomListFromLocal(id);
      
      await localResult.fold(
        (failure) async {
          AppLogger.warning(' [CustomLists] Failed to delete from local storage: ${failure.message}');
          // ローカル削除失敗時はロールバック
          state = AsyncValue.data(lists);
        },
        (_) async {
          // AppSettingsのcustomListOrderも更新（削除されたリストIDを除外）
          _updateCustomListOrderInSettings(updatedLists);
          
          // 2. Personal Listの場合、バックグラウンドでNostr削除（Phase E.6）
          if (!targetList.isGroup) {
            AppLogger.info('📤 [CustomLists] Deleting personal list from Nostr: ${targetList.name}');
            
            // Phase E.6: Nostrから動的にeventIdを取得してKind 5削除イベント送信
            _deletePersonalListFromNostr(targetList, lists);
          } else if (targetList.isGroup) {
            AppLogger.debug('ℹ️  [CustomLists] Group list deleted locally: ${targetList.name}');
          }
        },
      );
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

      // Phase C.3.1: Repository経由でローカルストレージに保存
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      result.fold(
        (failure) => AppLogger.warning(' Failed to reorder lists: ${failure.message}'),
        (_) {
          // AppSettingsのcustomListOrderも更新
          _updateCustomListOrderInSettings(updatedLists);
        },
      );
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
  
  /// Phase C.3.2.2: Nostrからカスタムリスト名を取得（Repository経由）
  /// 
  /// Kind 30001イベントのd tag（meiso-list-xxx）とtitle tagから
  /// カスタムリスト名のリストを抽出する
  Future<List<String>> fetchCustomListNamesFromNostr() async {
    try {
      // ✅ 復帰/起動直後の体感改善: 短時間での連続取得を間引く
      final last = localStorageService.getLastCustomListsSyncTime();
      if (last != null && DateTime.now().difference(last) < const Duration(minutes: 5)) {
        AppLogger.debug('📋 [CustomLists] Skip fetching list names (fresh)');
        return const <String>[];
      }

      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        AppLogger.warning('⚠️ [CustomLists] User pubkey not available, returning empty list');
        return [];
      }

      AppLogger.info('📋 [CustomLists] Fetching custom list names from Nostr...');

      // Phase C.3.2.2: Repository経由でリスト名を取得
      final result = await _repository.fetchCustomListNamesFromNostr(publicKey: userPubkey);

      return await result.fold(
        (failure) async {
          AppLogger.error('❌ [CustomLists] Failed to fetch list names: ${failure.message}');
          return <String>[];
        },
        (listNames) async {
          AppLogger.info('✅ [CustomLists] Fetched ${listNames.length} custom list names');
          // 次回の復帰/起動での余計な取得を避けるため保存
          await localStorageService.setLastCustomListsSyncTime(DateTime.now());
          return listNames;
        },
      );
    } catch (e, st) {
      AppLogger.error('❌ [CustomLists] Failed to fetch list names', error: e, stackTrace: st);
      return <String>[];
    }
  }

  /// Issue #80: kind 5削除イベントを同期
  /// Phase C.3.2.1: Repository経由で実装
  Future<void> syncDeletionEvents() async {
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        AppLogger.warning('🗑️ [CustomLists] User pubkey not available, skipping deletion sync');
        return;
      }
      
      AppLogger.info('🗑️ [CustomLists] Syncing deletion events (kind 5)...');
      
      // Phase C.3.2.1: Repository経由で削除イベントを取得
      final syncResult = await _repository.syncDeletionEvents(publicKey: userPubkey);
      
      await syncResult.fold(
        (failure) {
          AppLogger.error('❌ [CustomLists] Failed to sync deletion events: ${failure.message}');
        },
        (deletedIds) async {
          if (deletedIds.isNotEmpty) {
            _deletedEventIds.addAll(deletedIds);
            
            // Repository経由で保存
            final saveResult = await _repository.saveDeletedEventIds(_deletedEventIds);
            
            saveResult.fold(
              (failure) => AppLogger.error('❌ [CustomLists] Failed to save deletion events: ${failure.message}'),
              (_) => AppLogger.info('✅ [CustomLists] Synced ${deletedIds.length} deletion events (total: ${_deletedEventIds.length})'),
            );
          } else {
            AppLogger.info('ℹ️ [CustomLists] No deletion events found');
          }
        },
      );
    } catch (e, st) {
      AppLogger.error('❌ [CustomLists] Failed to sync deletion events', error: e, stackTrace: st);
    }
  }
  
  /// 削除済みイベントIDをチェックして、リストをフィルタリング
  List<CustomList> _filterDeletedLists(List<CustomList> lists) {
    if (_deletedEventIds.isEmpty) {
      return lists;
    }
    
    // kind 30001イベントの場合、d tagがリストIDになる
    // カスタムリストのIDがkind 30001のd tagと一致する場合、削除済みとみなす
    final filtered = lists.where((list) {
      // グループリストの場合、eventIdをチェック
      // 個人リストの場合、リスト名から生成されたIDをチェック
      // 注: kind 30001のイベントIDは「pubkey:30001:d-tag」のようになっているが、
      //     ここでは単純にリストIDが削除済みイベントIDに含まれるかチェック
      
      // 削除済みイベントIDのセットに含まれていたら除外
      return !_deletedEventIds.contains(list.id);
    }).toList();
    
    if (filtered.length < lists.length) {
      AppLogger.info('🗑️ [CustomLists] Filtered out ${lists.length - filtered.length} deleted lists');
    }
    
    return filtered;
  }
  
  /// Nostrから同期されたカスタムリストを反映
  /// listNameのListを受け取り、ローカルにないリストを追加
  Future<void> syncListsFromNostr(List<String> nostrListNames) async {
    // Issue #80: 最初に削除イベントを同期
    await syncDeletionEvents();
    
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
      // AsyncLoadingやAsyncErrorの場合は、Repository経由で読み込む
      AppLogger.warning(' [CustomLists] State is ${currentState.runtimeType}, loading from local storage');
      final result = await _repository.loadCustomListsFromLocal();
      currentLists = result.fold(
        (failure) {
          AppLogger.warning(' [CustomLists] Failed to load: ${failure.message}');
          return <CustomList>[];
        },
        (lists) => lists,
      );
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
    
    // Issue #80: 削除済みリストをフィルタリング
    final filteredLists = _filterDeletedLists(updatedLists);
    
    // 変更があった場合、または stateの更新が必要な場合
    if (hasChanges || needsStateUpdate) {
      if (hasChanges) {
        AppLogger.info(' [CustomLists] 💾 Saving changes to local storage...');
        
        // AppSettingsから順番を復元
        await _applySavedListOrder(filteredLists);
        
        // Phase C.3.1: Repository経由でローカルストレージに保存
        final result = await _repository.saveCustomListsToLocal(filteredLists);
        result.fold(
          (failure) => AppLogger.warning(' [CustomLists] Failed to save: ${failure.message}'),
          (_) => AppLogger.debug(' [CustomLists] Saved successfully'),
        );
      }
      
      // 状態を更新（UIに確実に通知）
      // hasChangesがfalseでも、AsyncLoadingから読み込んだ場合は更新が必要
      AppLogger.info(' [CustomLists] 🔄 Updating state with ${filteredLists.length} lists...');
      state = AsyncValue.data(filteredLists);
      AppLogger.info(' [CustomLists] ✅ State updated successfully! UI should now reflect ${filteredLists.length} lists');
      
      if (hasChanges) {
        AppLogger.info(' [CustomLists] ✅ Synced ${nostrListNames.length} lists from Nostr (added ${updatedLists.length - currentLists.length} new)');
      }
    } else {
      AppLogger.info(' [CustomLists] ⏭️  No changes needed (all lists already synced and state is up-to-date)');
    }
    
    // Nostr同期後、リストが空の場合はデフォルトリストを作成
    await createDefaultListsIfEmpty();
  }
  
  /// グループ招待を同期（Phase 6.4: MLS招待システム）
  Future<void> syncGroupInvitations() async {
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        AppLogger.warning('📥 [GroupInvitations] User pubkey not available, skipping sync');
        return;
      }
      
      AppLogger.info('📥 [GroupInvitations] Syncing group invitations...');
      
      // Phase D.5: SyncGroupInvitationsUseCaseを使用
      final syncInvitationsUseCase = _ref.read(mls_usecase.syncGroupInvitationsUseCaseProvider);
      final result = await syncInvitationsUseCase(SyncGroupInvitationsParams(
        recipientPublicKey: userPubkey,
      ));
      
      // 🔥 Phase D.9.1: fold()の両方のコールバックをasyncに統一
      await result.fold(
        (failure) async {
          AppLogger.error('❌ [GroupInvitations] Sync failed: ${failure.message}');
        },
        (invitations) async {
          AppLogger.info('✅ [GroupInvitations] Found ${invitations.length} pending invitations');
          
          if (invitations.isEmpty) {
            return;
          }
          
          // 🔥 Phase D.9.1: state.whenData()をvalueOrNullに変更（Phase D.5と同じ修正）
          // stateがloadingの場合もデータを取得できるようにする
          final currentLists = state.valueOrNull ?? <CustomList>[];
          final updatedLists = List<CustomList>.from(currentLists);
          bool hasChanges = false;
          
          for (final invitation in invitations) {
            // 既にこのグループのリストが存在するか確認
            final existingIndex = updatedLists.indexWhere((list) => list.id == invitation.groupId);
            
            if (existingIndex == -1) {
              // 新しい招待として追加
              AppLogger.info('📨 [GroupInvitations] New invitation: ${invitation.groupName} from ${invitation.inviterPubkey.substring(0, 16)}...');
              
              final newList = CustomList(
                id: invitation.groupId,
                name: invitation.groupName.toUpperCase(),
                order: _getNextOrder(updatedLists),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isGroup: true,
                isPendingInvitation: true,
                inviterNpub: invitation.inviterPubkey, // hex形式（npub変換は後で必要に応じて）
                inviterName: invitation.inviterName,
                welcomeMsg: invitation.welcomeMessage,
                groupMembers: [], // 招待受諾後に設定
              );
              
              updatedLists.add(newList);
              hasChanges = true;
            } else {
              // 既存のリストを更新（招待情報を追加）
              final existingList = updatedLists[existingIndex];
              if (!existingList.isPendingInvitation) {
                AppLogger.info('📨 [GroupInvitations] Updating existing list with invitation: ${invitation.groupName}');
                
                updatedLists[existingIndex] = existingList.copyWith(
                  isPendingInvitation: true,
                  inviterNpub: invitation.inviterPubkey,
                  inviterName: invitation.inviterName,
                  welcomeMsg: invitation.welcomeMessage,
                );
                hasChanges = true;
              }
            }
          }
          
          if (hasChanges) {
            // Phase C.3.1: Repository経由でローカルストレージに保存
            final saveResult = await _repository.saveCustomListsToLocal(updatedLists);
            
            saveResult.fold(
              (failure) => AppLogger.warning('⚠️ [GroupInvitations] Failed to save: ${failure.message}'),
              (_) {
                // 状態を更新
                state = AsyncValue.data(updatedLists);
                AppLogger.info('✅ [GroupInvitations] Synced ${invitations.length} group invitations');
              },
            );
          }
        },
      );
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [GroupInvitations] Failed to sync group invitations', error: e, stackTrace: stackTrace);
      
      // 🔥 Phase D.9.1: エラー時もstateを保持（Phase D.5と同じ修正）
      // stateがloadingのまま残ると無限ローディングが発生する
      final currentLists = state.valueOrNull ?? <CustomList>[];
      state = AsyncValue.data(currentLists);
      
      AppLogger.info('✅ [GroupInvitations] State restored to data after error');
    }
  }
  
  /// Phase 8.1.2: 招待通知の自動同期タイマーを開始
  void _startInvitationSyncTimer() {
    // 5分ごとに同期
    const syncInterval = Duration(minutes: 5);
    
    _invitationSyncTimer = Timer.periodic(syncInterval, (timer) async {
      AppLogger.debug('🔄 [GroupInvitations] Auto-sync triggered (timer)');
      try {
        await syncGroupInvitations();
      } catch (e) {
        AppLogger.warning('⚠️ [GroupInvitations] Auto-sync failed', error: e);
        // エラーは無視（次回の同期で再試行）
      }
    });
    
    AppLogger.info('⏱️ [GroupInvitations] Auto-sync timer started (interval: $syncInterval)');
  }
  
  /// Phase 8.1.2: 招待通知の自動同期タイマーを停止
  void _stopInvitationSyncTimer() {
    _invitationSyncTimer?.cancel();
    _invitationSyncTimer = null;
    AppLogger.info('⏱️ [GroupInvitations] Auto-sync timer stopped');
  }
  
  @override
  void dispose() {
    _stopInvitationSyncTimer();
    super.dispose();
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
      
      // Phase C.3.1: Repository経由でローカルに追加
      final updatedLists = [...lists, newGroupList];
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      return result.fold(
        (failure) {
          AppLogger.error('❌ [CustomLists] Failed to save group list: ${failure.message}');
          return null;
        },
        (_) {
          state = AsyncValue.data(updatedLists);
          
          // AppSettingsのcustomListOrderも更新
          _updateCustomListOrderInSettings(updatedLists);
          
          AppLogger.info('✅ [CustomLists] Created group list: "$normalizedName" with ${memberPubkeys.length} members');
          return newGroupList;
        },
      );
    } catch (e, st) {
      AppLogger.error('❌ Failed to create group list: $e', error: e, stackTrace: st);
      return null;
    }
  }
  
  /// Phase 8.1/8.4: MLSグループリスト作成 + 招待送信
  /// Phase 8.2: エラーハンドリング強化
  Future<CustomList?> createMlsGroupList({
    required String name,
    required List<String> keyPackages,
    required List<String> memberNpubs, // Phase 8.4: 招待送信用
  }) async {
    if (name.trim().isEmpty) return null;
    
    try {
      final lists = await state.whenData((lists) => lists).value ?? [];
      
      final now = DateTime.now();
      final normalizedName = name.trim().toUpperCase();
      
      // グループIDを生成
      const uuid = Uuid();
      final groupId = uuid.v4();
      
      AppLogger.info('🔐 [CustomLists] Creating MLS group: "$normalizedName"');
      AppLogger.info('   Members: ${memberNpubs.length}');
      
      // Phase D.5: CreateMlsGroupUseCaseを使用
      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        throw Exception('User public key not available');
      }
      
      final createGroupUseCase = _ref.read(mls_usecase.createMlsGroupUseCaseProvider);
      final groupResult = await createGroupUseCase(CreateMlsGroupParams(
        publicKey: userPubkey,
        groupId: groupId,
        groupName: normalizedName,
        keyPackages: keyPackages,
      ));
      
      final String welcomeMsgBase64 = await groupResult.fold(
        (failure) {
          throw Exception(failure.message);
        },
        (mlsGroup) {
          AppLogger.info('✅ [CustomLists] MLS group created');
          if (mlsGroup.welcomeMessage == null) {
            throw Exception('Welcome message is null');
          }
          return mlsGroup.welcomeMessage!; // MlsGroupエンティティからwelcomeMessageを取得
        },
      );
      
      // Phase 8.4: Welcome Messageを各メンバーに送信
      
      AppLogger.info('📤 [CustomLists] Sending invitations to ${memberNpubs.length} members...');
      
      int successCount = 0;
      int failCount = 0;
      
      // Phase D.5: SendGroupInvitationUseCaseを使用
      final sendInvitationUseCase = _ref.read(mls_usecase.sendGroupInvitationUseCaseProvider);
      
      for (int i = 0; i < memberNpubs.length; i++) {
        final npub = memberNpubs[i];
        try {
          AppLogger.info('📤 [CustomLists] Sending invitation ${i + 1}/${memberNpubs.length} to ${npub.substring(0, 20)}...');
          
          final invitationResult = await sendInvitationUseCase(SendGroupInvitationParams(
            recipientNpub: npub,
            groupId: groupId,
            groupName: normalizedName,
            welcomeMessage: welcomeMsgBase64,
          ));
          
          await invitationResult.fold(
            (failure) {
              AppLogger.warning('  ⚠️ Invitation failed: ${failure.message}');
              failCount++;
            },
            (result) {
              if (result.success && result.eventId != null) {
                AppLogger.info('  ✅ Invitation sent successfully! Event ID: ${result.eventId!.substring(0, 16)}...');
                successCount++;
              } else {
                AppLogger.warning('  ⚠️ Invitation failed (returned null)');
                failCount++;
              }
            },
          );
        } catch (e) {
          final appError = ErrorHandler.classify(e);
          AppLogger.error(
            '  ❌ Invitation error: ${appError.userMessage}',
            error: e,
          );
          failCount++;
          // エラーがあっても次のメンバーに送信を続ける
        }
      }
      
      AppLogger.info('✅ [CustomLists] Invitations sent: $successCount success, $failCount failed');
      
      // Phase 8.1.3: 招待送信が全て失敗した場合はエラー
      if (successCount == 0 && memberNpubs.isNotEmpty) {
        AppLogger.error('❌ [CustomLists] All invitations failed to send');
        throw Exception('招待送信が全て失敗しました。メンバーのnpubを確認してください。');
      }
      
      // 一部失敗した場合は警告ログを出力
      if (failCount > 0) {
        AppLogger.warning('⚠️ [CustomLists] Some invitations failed: $failCount/${ memberNpubs.length}');
      }
      
      // ローカルにグループリストを作成
      final newGroupList = CustomList(
        id: groupId,
        name: normalizedName,
        order: _getNextOrder(lists),
        createdAt: now,
        updatedAt: now,
        isGroup: true,
        groupMembers: [],
      );
      
      // Phase C.3.1: Repository経由でローカルストレージに保存
      final updatedLists = [...lists, newGroupList];
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      return result.fold(
        (failure) {
          AppLogger.error('❌ [CustomLists] Failed to save MLS group list: ${failure.message}');
          return null;
        },
        (_) {
          state = AsyncValue.data(updatedLists);
          _updateCustomListOrderInSettings(updatedLists);
          return newGroupList;
        },
      );
    } catch (e, st) {
      final appError = ErrorHandler.classify(e, stackTrace: st);
      AppLogger.error(
        '❌ [CustomLists] Failed to create MLS group\n'
        'Category: ${appError.category}\n'
        'User Message: ${appError.userMessage}',
        error: e,
        stackTrace: st,
      );
      
      // Phase 8.2.4: MLS固有エラーの処理
      if (appError.category == ErrorCategory.mls && appError.isRetryable) {
        AppLogger.info('💡 [CustomLists] MLS error is retryable, consider retry');
      }
      
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
      
      // Phase C.3.1: Repository経由でローカルストレージに保存
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      result.fold(
        (failure) => AppLogger.warning('⚠️ Failed to add member: ${failure.message}'),
        (_) {
          state = AsyncValue.data(updatedLists);
          AppLogger.info('✅ Added member to group list: ${groupList.name}');
        },
      );
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
      
      // Phase C.3.1: Repository経由でローカルストレージに保存
      final result = await _repository.saveCustomListsToLocal(updatedLists);
      
      result.fold(
        (failure) => AppLogger.warning('⚠️ Failed to remove member: ${failure.message}'),
        (_) {
          state = AsyncValue.data(updatedLists);
          AppLogger.info('✅ Removed member from group list: ${groupList.name}');
        },
      );
    }).value;
  }
  
  /// Nostrからグループリストを同期
  /// 
  /// ⚠️ Phase 8.4: kind: 30001グループは廃止されました
  /// MLSグループのみを使用します（Phase 8.1で完全統合済み）
  @Deprecated('kind: 30001 group sync is disabled. Use MLS groups only.')
  Future<void> syncGroupListsFromNostr() async {
    // Phase 8.4: kind: 30001グループの同期を無効化
    // パフォーマンス問題の原因となっていたため、MLSグループのみを使用
    AppLogger.info('ℹ️ [Phase 8.4] kind: 30001 group sync is disabled. Use MLS groups only.');
    return;
    
    // 以下のコードは参考用に残す（将来の互換性レイヤー実装時に使用可能）
    /*
    try {
      // Issue #80: 最初に削除イベントを同期
      await syncDeletionEvents();
      
      AppLogger.info('🔄 Syncing group lists from Nostr...');
      
      // 公開鍵を取得
      var publicKey = _ref.read(publicKeyProvider);
      var npub = _ref.read(nostrPublicKeyProvider);
      
      // 公開鍵がnullの場合、復元を試みる
      if (publicKey == null || npub == null) {
        AppLogger.warning(' 公開鍵が未設定、復元を試みます...');
        try {
          final nostrService = _ref.read(nostrServiceProvider);
          publicKey = await nostrService.getPublicKey();
          if (publicKey != null) {
            AppLogger.info(' hex公開鍵を復元: ${publicKey.substring(0, 16)}...');
            _ref.read(publicKeyProvider.notifier).state = publicKey;
            
            npub = await nostrService.hexToNpub(publicKey);
            _ref.read(nostrPublicKeyProvider.notifier).state = npub;
            AppLogger.info(' npub公開鍵も復元: ${npub.substring(0, 16)}...');
          } else {
            throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
          }
        } catch (e) {
          AppLogger.error(' 公開鍵の復元に失敗: $e');
          throw Exception('公開鍵が設定されていません: $e');
        }
      }
      
      // Nostrからグループリストを取得
      final groupLists = await groupTaskService.syncGroupLists(
        publicKey: publicKey,
        npub: npub,
      );
      
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
      
      // Issue #80: 削除済みリストをフィルタリング
      final filteredLists = _filterDeletedLists(updatedLists);
      
      // 変更があった場合、または stateの更新が必要な場合
      if (hasChanges || needsStateUpdate) {
        if (hasChanges) {
          // ローカルストレージに保存
          await localStorageService.saveCustomLists(filteredLists);
          
          // AppSettingsのcustomListOrderも更新
          await _updateCustomListOrderInSettings(filteredLists);
        }
        
        // 状態を更新（UIに確実に通知）
        // hasChangesがfalseでも、AsyncLoadingから読み込んだ場合は更新が必要
        state = AsyncValue.data(filteredLists);
        
        AppLogger.info('✅ Synced ${groupLists.length} group lists from Nostr');
        AppLogger.info('📱 State updated successfully! UI should now reflect ${filteredLists.length} total lists');
      }
    } catch (e, st) {
      AppLogger.error('❌ Failed to sync group lists from Nostr: $e', error: e, stackTrace: st);
    }
    */
  }

  /// Personal ListをNostrから削除（Phase E.6）
  /// 
  /// 動作:
  /// 1. RustからeventIdを動的に取得
  /// 2. DeletePersonalListUseCaseでKind 5削除イベント送信
  /// 3. エラー時はロールバック
  Future<void> _deletePersonalListFromNostr(
    CustomList targetList,
    List<CustomList> originalLists,
  ) async {
    try {
      // 1. NostrからeventIdを検索
      AppLogger.debug('🔍 [CustomLists] Searching for event ID: list_id=${targetList.id}');
      
      final nostrService = _ref.read(nostrServiceProvider);
      final publicKey = await nostrService.getPublicKey();
      
      if (publicKey == null) {
        AppLogger.warning('⚠️  [CustomLists] Public key not available');
        return;
      }
      
      final eventId = await rust_api.findPersonalListEventId(
        listId: targetList.id,
        publicKeyHex: publicKey,
      );
      
      if (eventId == null) {
        AppLogger.warning('⚠️  [CustomLists] Event ID not found for list: ${targetList.name}');
        AppLogger.info('ℹ️  [CustomLists] List was deleted locally, but no Nostr event exists');
        return;
      }
      
      AppLogger.info('✅ [CustomLists] Found event ID: ${eventId.substring(0, 16)}...');
      
      // 2. DeletePersonalListUseCaseでKind 5削除イベント送信
      final deleteUseCase = _ref.read(deletePersonalListUseCaseProvider);
      final isAmberMode = _ref.read(isAmberModeProvider);
      
      final result = await deleteUseCase(DeletePersonalListParams(
        list: targetList,
        eventId: eventId,
        isAmberMode: isAmberMode,
      ));
      
      // 3. エラー時はロールバック
      await result.fold(
        (failure) async {
          AppLogger.error('❌ [CustomLists] Failed to delete from Nostr: ${failure.message}');
          
          // ローカルに復元
          AppLogger.info('♻️  [CustomLists] Rolling back: restoring list to local storage');
          final restoreResult = await _repository.saveCustomListToLocal(targetList);
          
          await restoreResult.fold(
            (restoreFailure) {
              AppLogger.error('❌ [CustomLists] Failed to restore list: ${restoreFailure.message}');
            },
            (_) {
              // UI更新: リストを復元
              final currentState = state.valueOrNull ?? [];
              final restoredLists = [...currentState, targetList]
                ..sort((a, b) => a.order.compareTo(b.order));
              state = AsyncValue.data(restoredLists);
              
              AppLogger.info('✅ [CustomLists] List restored after Nostr deletion failure: ${targetList.name}');
            },
          );
        },
        (_) {
          AppLogger.info('✅ [CustomLists] Successfully deleted personal list from Nostr: ${targetList.name}');
        },
      );
    } catch (e, stack) {
      AppLogger.error('❌ [CustomLists] Unexpected error during Nostr deletion: $e');
      AppLogger.error('Stack trace: $stack');
      
      // ローカルに復元
      final restoreResult = await _repository.saveCustomListToLocal(targetList);
      await restoreResult.fold(
        (failure) {
          AppLogger.error('❌ [CustomLists] Failed to restore list: ${failure.message}');
        },
        (_) {
          final currentState = state.valueOrNull ?? [];
          final restoredLists = [...currentState, targetList]
            ..sort((a, b) => a.order.compareTo(b.order));
          state = AsyncValue.data(restoredLists);
          
          AppLogger.info('♻️  [CustomLists] List restored after unexpected error: ${targetList.name}');
        },
      );
    }
  }
}

