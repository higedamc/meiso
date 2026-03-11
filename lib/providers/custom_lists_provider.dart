import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/features/custom_list/domain/repositories/custom_list_repository.dart';
import 'package:uuid/uuid.dart';
import '../services/logger_service.dart';
import '../models/custom_list.dart';
// Phase 8.4: group_task_service.dart は kind: 30001廃止により未使用
import 'app_settings_provider.dart';
import 'nostr_provider.dart';
import 'todos_provider.dart'; // Issue #101: リスト再作成時のタスクID削除
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
// Issue #102: MLS Repository統合（グループ復元用）
import '../features/mls/infrastructure/providers/repository_providers.dart' as mls_repo;
import '../core/common/failure.dart';
// Rust FFI
import '../bridge_generated.dart/api.dart' as rust_api;

/// カスタムリストを管理するProvider
final customListsProvider =
    StateNotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>(
  CustomListsNotifier.new,
);

class CustomListsNotifier extends StateNotifier<AsyncValue<List<CustomList>>> {
  CustomListsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initialize();
    _startInvitationSyncTimer();
  }
  
  final Ref _ref;
  
  /// Phase C.3.1: Repository経由でローカルCRUD操作
  /// MLS機能はProvider内に保持（Phase Dで移行予定）
  late final CustomListRepository _repository = _ref.read(customListRepositoryProvider);
  Timer? _invitationSyncTimer;
  
  /// Issue #80: 削除済みイベントメタデータ（kind 5で削除されたリスト + LWW対応）
  /// Map<eventId, deletion_created_at>
  Map<String, int> _deletedEventMetadata = {};
  
  /// Issue #101: 削除済みリストメタデータ（list_idベース + LWW対応）
  /// Map<listId, deletion_created_at>
  Map<String, int> _deletedListMetadata = {};
  
  /// MLS: ローカル削除済みMLSグループリストID（ローカルのみ、Nostrには送信しない）
  /// Set<listId>
  Set<String> _deletedMlsGroupListIds = {};

  Future<void> _initialize() async {
    try {
      // Issue #80: Phase C.3.2.1 - Repository経由で削除済みイベントメタデータを読み込み（LWW対応）
      final deletedEventsResult = await _repository.loadDeletedEventMetadata();
      deletedEventsResult.fold(
        (failure) {
          AppLogger.warning('🗑️ [CustomLists] Failed to load deleted event metadata: ${failure.message}');
          _deletedEventMetadata = {};
        },
        (metadata) {
          _deletedEventMetadata = metadata;
          AppLogger.info('🗑️ [CustomLists] Loaded ${_deletedEventMetadata.length} deleted event metadata (LWW)');
        },
      );
      
      // Issue #101: 削除済みリストメタデータを読み込み（LWW対応）
      final deletedListsResult = await _repository.loadDeletedListMetadata();
      deletedListsResult.fold(
        (failure) {
          AppLogger.warning('🗑️ [CustomLists] [Issue#101] Failed to load deleted list metadata: ${failure.message}');
          _deletedListMetadata = {};
        },
        (metadata) {
          _deletedListMetadata = metadata;
          AppLogger.info('🗑️ [CustomLists] [Issue#101] Loaded ${_deletedListMetadata.length} deleted list metadata (LWW)');
        },
      );
      
      // MLS: ローカル削除済みMLSグループリストIDを読み込み
      final deletedMlsGroupListsResult = await _repository.loadDeletedMlsGroupListIds();
      deletedMlsGroupListsResult.fold(
        (Failure failure) {
          AppLogger.warning('🗑️ [MLS] Failed to load deleted MLS group list IDs: ${failure.message}');
          _deletedMlsGroupListIds = {};
        },
        (Set<String> ids) {
          _deletedMlsGroupListIds = ids;
          AppLogger.info('🗑️ [MLS] Loaded ${_deletedMlsGroupListIds.length} deleted MLS group list IDs');
        },
      );
      
      // Phase C.3.1: Repository経由でローカルストレージから読み込み
      final listsResult = await _repository.loadCustomListsFromLocal();
      
      listsResult.fold(
        (failure) {
          AppLogger.warning(' [CustomLists] Failed to load lists: ${failure.message}');
          if (state is! AsyncData<List<CustomList>>) {
            state = const AsyncValue.data([]);
          }
        },
        (localLists) async {
          // 既にNostr同期でstateが更新されていれば上書きしない（同期が先に完了した場合）
          final current = state.valueOrNull;
          if (current != null && current.isNotEmpty) {
            AppLogger.debug(' [CustomLists] Skipping init state (already have ${current.length} lists from sync)');
            return;
          }
          if (localLists.isEmpty) {
            AppLogger.info(' [CustomLists] No local lists found. Waiting for Nostr sync...');
            if (state is! AsyncData<List<CustomList>>) {
              state = const AsyncValue.data([]);
            }
          } else {
            // AppSettingsから保存された順番を適用
            await _applySavedListOrder(localLists);
            final filteredLists = await _filterDeletedLists(localLists);
            if (filteredLists.length < localLists.length) {
              AppLogger.info('🗑️ [MLS] Filtered ${localLists.length - filteredLists.length} deleted MLS groups on init');
              await _repository.saveCustomListsToLocal(filteredLists);
            }
            AppLogger.info(' [CustomLists] Loaded ${filteredLists.length} lists from local storage');
            state = AsyncValue.data(filteredLists);
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
        
        // Issue #102 (MLS Zombie Lists): 承認済みMLSグループの復元
        // アプリ再インストール後、MLSローカルステートが消失するため、
        // Welcome Messageを再処理してグループに再参加する
        try {
          await _restoreMlsGroupStates();
        } catch (e) {
          AppLogger.warning('🔄 [MLSRestore] MLS group restoration failed: $e');
        }
      });
    } catch (e) {
      AppLogger.warning(' CustomList初期化エラー: $e');
      state = const AsyncValue.data([]);
    }
  }

  /// 初回起動時のデフォルトリストを作成（Nostr同期後にリストが空の場合のみ）
  Future<void> createDefaultListsIfEmpty() async {
    // 🔥 Phase 8.7: Bug #2修正 - state.whenData() → valueOrNull に変更
    final lists = state.valueOrNull;
    if (lists == null) {
      AppLogger.warning(' [CustomLists] CustomListsProvider state is null, cannot create default lists.');
      return;
    }
    
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
  }

  /// 新しいリストを追加
  Future<void> addList(String name) async {
    if (name.trim().isEmpty) return;

    // 🔥 Phase 8.7: Bug #2修正 - state.whenData() → valueOrNull に変更
    final lists = state.valueOrNull;
    if (lists == null) {
      AppLogger.warning(' [CustomLists] CustomListsProvider state is null, cannot add list.');
      return;
    }

    final now = DateTime.now();
    final normalizedName = name.trim().toUpperCase();
    
    // リスト名から決定的なIDを生成（NIP-51準拠）
    final listId = CustomListHelpers.generateIdFromName(normalizedName);
    
    // 同じIDのリストが既に存在するかチェック
    if (lists.any((list) => list.id == listId)) {
      AppLogger.warning(' List with ID "$listId" already exists');
      return;
    }
    
    // Issue #101: 削除済みリストの再作成を許可（LWW対応）
    final creationTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Unix timestamp
    var removedFromMetadata = false;
    
    // listIdベースの削除メタデータをチェック
    if (_deletedListMetadata.containsKey(listId)) {
      final deletionTime = _deletedListMetadata[listId]!;
      
      // LWW: 新しい作成は古い削除を上書き
      if (creationTime > deletionTime) {
        AppLogger.info('🔄 [CustomLists] LWW: Re-creating list "$normalizedName" (creation: $creationTime > deletion: $deletionTime)');
        _deletedListMetadata.remove(listId);
        final saveResult = await _repository.saveDeletedListMetadata(_deletedListMetadata);
        saveResult.fold(
          (failure) => AppLogger.warning('⚠️  [CustomLists] Failed to remove from list metadata: ${failure.message}'),
          (_) {
            AppLogger.info('✅ [CustomLists] Removed from list deletion metadata (remaining: ${_deletedListMetadata.length})');
            removedFromMetadata = true;
          },
        );
      } else {
        AppLogger.warning('⚠️  [CustomLists] LWW: Cannot recreate list "$normalizedName" (creation: $creationTime <= deletion: $deletionTime)');
        // 理論的には起こらないはずだが、念のため
      }
    }
    
    // event_idベースの削除メタデータもチェック（Nostr上の古いイベントID）
    if (_deletedEventMetadata.isNotEmpty) {
      final nostrService = _ref.read(nostrServiceProvider);
      final publicKey = await nostrService.getPublicKey();
      
      if (publicKey != null) {
        try {
          final oldEventId = await rust_api.findPersonalListEventId(
            listId: listId,
            publicKeyHex: publicKey,
          );
          
          if (oldEventId != null && _deletedEventMetadata.containsKey(oldEventId)) {
            final deletionTime = _deletedEventMetadata[oldEventId]!;
            
            // LWW: 新しい作成は古い削除を上書き
            if (creationTime > deletionTime) {
              AppLogger.info('🔄 [CustomLists] LWW: Removing old event deletion metadata: ${oldEventId.substring(0, 16)}...');
              _deletedEventMetadata.remove(oldEventId);
              final saveResult = await _repository.saveDeletedEventMetadata(_deletedEventMetadata);
              saveResult.fold(
                (failure) => AppLogger.warning('⚠️  [CustomLists] Failed to remove from event metadata: ${failure.message}'),
                (_) {
                  AppLogger.info('✅ [CustomLists] Removed from event deletion metadata (remaining: ${_deletedEventMetadata.length})');
                  removedFromMetadata = true;
                },
              );
            }
          }
        } catch (e) {
          AppLogger.debug('ℹ️  [CustomLists] Could not find old event ID (this is OK for new list): $e');
        }
      }
    }
    
    if (removedFromMetadata) {
      AppLogger.info('♻️  [CustomLists] List "$normalizedName" is now ready for re-creation (LWW)');
      
      // Issue #101: リスト再作成時に、そのリストに関連する削除済みタスクIDをクリア
      AppLogger.info('🔄 [Issue#101] Clearing deleted todo IDs for re-created list: $listId');
      await _ref.read(todosProvider.notifier).clearDeletedTodoIdsForList(listId);
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
  }

  /// リストを更新
  Future<void> updateList(CustomList list) async {
    // 🔥 Phase D.9.2: state.whenData() → valueOrNull に変更
    // syncGroupInvitations() と並行実行される場合にレースコンディションが発生するため
    final lists = state.valueOrNull ?? [];
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
    // 🔥 Phase 8.7: Bug #2修正 - state.whenData() → valueOrNull に変更
    // syncListsFromNostr() と並行実行される場合にレースコンディションが発生するため
    
    // Issue #101: state.valueOrNullがnullの場合、Repositoryから読み込む
    List<CustomList> lists;
    if (state.valueOrNull != null) {
      lists = state.valueOrNull!;
    } else {
      AppLogger.warning('⚠️  [CustomLists] State is null, loading from repository...');
      final result = await _repository.loadCustomListsFromLocal();
      lists = result.fold(
        (failure) {
          AppLogger.error('❌ [CustomLists] Failed to load lists from repository: ${failure.message}');
          return <CustomList>[];
        },
        (loadedLists) => loadedLists,
      );
      
      if (lists.isEmpty) {
        AppLogger.error('❌ [CustomLists] Cannot delete list: no lists available');
        return;
      }
    }
    
    // 削除対象リストを取得
    final targetIndex = lists.indexWhere((l) => l.id == id);
    if (targetIndex == -1) {
      AppLogger.warning('⚠️  [CustomLists] List with id $id not found in ${lists.length} lists');
      AppLogger.debug('   Available list IDs: ${lists.map((l) => l.id).join(", ")}');
      return;
    }
    
    final targetList = lists[targetIndex];
    
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
        
        // 2. 削除処理をリストタイプで分岐
        if (!targetList.isGroup) {
          // 2-1. Personal List: Nostrに削除イベント送信 + LWWメタデータ記録
          AppLogger.info('📤 [CustomLists] Deleting personal list from Nostr: ${targetList.name}');
          
          // Issue #101: 削除済みリストメタデータに追加（LWW対応）
          final deletionTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Unix timestamp
          _deletedListMetadata[id] = deletionTime;
          final saveMetadataResult = await _repository.saveDeletedListMetadata(_deletedListMetadata);
          saveMetadataResult.fold(
            (failure) => AppLogger.warning('⚠️  [CustomLists] [Issue#101] Failed to save deleted list metadata: ${failure.message}'),
            (_) => AppLogger.info('🗑️  [CustomLists] [Issue#101] Added list to deletion metadata: $id (time: $deletionTime, total: ${_deletedListMetadata.length})'),
          );
          
          // Phase E.6: Nostrから動的にeventIdを取得してKind 5削除イベント送信
          _deletePersonalListFromNostr(targetList, lists);
        } else {
          // 2-2. MLS Group List: ローカル削除のみ（Nostrには送信しない）
          AppLogger.info('🗑️  [MLS] Locally deleting MLS group list: ${targetList.name}');
          
          _deletedMlsGroupListIds.add(id);
          final saveMlsResult = await _repository.saveDeletedMlsGroupListIds(_deletedMlsGroupListIds);
          saveMlsResult.fold(
            (Failure failure) => AppLogger.warning('⚠️  [MLS] Failed to save deleted MLS group list ID: ${failure.message}'),
            (void _) => AppLogger.info('🗑️  [MLS] Added to deleted MLS group list IDs: $id (total: ${_deletedMlsGroupListIds.length})'),
          );
        }
      },
    );
  }

  /// リストを並び替え
  Future<void> reorderLists(int oldIndex, int newIndex) async {
    // 🔥 Phase 8.7: Bug #2修正 - state.whenData() → valueOrNull に変更
    final lists = state.valueOrNull;
    if (lists == null) {
      AppLogger.warning(' [CustomLists] CustomListsProvider state is null, cannot reorder lists.');
      return;
    }

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
  
  /// Phase C.3.2.2: Nostrからカスタムリストメタデータを取得（Repository経由、LWW対応）
  /// 
  /// Kind 30001イベントのd tag（meiso-list-xxx）とtitle tag、created_atを取得
  /// LWW比較用に (listId, listName, eventId, created_at) のタプルを返す
  Future<List<(String, String, String, int)>> fetchCustomListMetadataFromNostr() async {
    try {
      // ✅ 復帰/起動直後の体感改善: 短時間での連続取得を間引く
      final last = localStorageService.getLastCustomListsSyncTime();
      if (last != null && DateTime.now().difference(last) < const Duration(minutes: 5)) {
        AppLogger.debug('📋 [CustomLists] Skip fetching list metadata (fresh)');
        return const <(String, String, String, int)>[];
      }

      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        AppLogger.warning('⚠️ [CustomLists] User pubkey not available, returning empty list');
        return [];
      }

      AppLogger.info('📋 [CustomLists] Fetching custom list metadata from Nostr (LWW)...');

      // Phase C.3.2.2: Repository経由でリストメタデータを取得（LWW対応）
      final result = await _repository.fetchCustomListMetadataFromNostr(
        publicKey: userPubkey,
      );

      return await result.fold(
        (failure) async {
          AppLogger.error('❌ [CustomLists] Failed to fetch list metadata: ${failure.message}');
          return <(String, String, String, int)>[];
        },
        (listMetadata) async {
          AppLogger.info('✅ [CustomLists] Fetched ${listMetadata.length} list metadata');
          // 次回の復帰/起動での余計な取得を避けるため保存
          await localStorageService.setLastCustomListsSyncTime(DateTime.now());
          return listMetadata;
        },
      );
    } catch (e, st) {
      AppLogger.error('❌ [CustomLists] Failed to fetch list metadata', error: e, stackTrace: st);
      return <(String, String, String, int)>[];
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
      
      AppLogger.info('🗑️ [CustomLists] Syncing deletion events (kind 5) with LWW...');
      
      // Phase C.3.2.1: Repository経由で削除イベントメタデータを取得（LWW対応）
      final syncResult = await _repository.syncDeletionEvents(publicKey: userPubkey);
      
      await syncResult.fold(
        (failure) {
          AppLogger.error('❌ [CustomLists] Failed to sync deletion events: ${failure.message}');
        },
        (metadata) async {
          if (metadata.isNotEmpty) {
            // 既存のメタデータとマージ（LWW: より新しいタイムスタンプを採用）
            for (final entry in metadata.entries) {
              final eventId = entry.key;
              final newDeletionTime = entry.value;
              
              if (_deletedEventMetadata.containsKey(eventId)) {
                final existingDeletionTime = _deletedEventMetadata[eventId]!;
                if (newDeletionTime > existingDeletionTime) {
                  _deletedEventMetadata[eventId] = newDeletionTime;
                  AppLogger.debug('🔄 [CustomLists] Updated deletion time for $eventId');
                }
              } else {
                _deletedEventMetadata[eventId] = newDeletionTime;
              }
            }
            
            // Repository経由で保存
            final saveResult = await _repository.saveDeletedEventMetadata(_deletedEventMetadata);
            
            saveResult.fold(
              (failure) => AppLogger.error('❌ [CustomLists] Failed to save deletion metadata: ${failure.message}'),
              (_) => AppLogger.info('✅ [CustomLists] Synced ${metadata.length} deletion events (total: ${_deletedEventMetadata.length})'),
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
  
  /// 削除済みメタデータをチェックして、リストをフィルタリング（LWW対応）
  /// Issue #101: LWW比較で削除/復元を判定
  Future<List<CustomList>> _filterDeletedLists(List<CustomList> lists) async {
    AppLogger.debug('🗑️ [CustomLists] Filtering lists (LWW + MLS key check)...');
    
    // eventIdがない場合、Rustから検索して設定する
    final publicKey = await _ref.read(nostrServiceProvider).getPublicKey();
    
    final filtered = <CustomList>[];
    for (final list in lists) {
      // MLSグループリストの特別処理
      if (list.isGroup) {
        // 1. ローカル削除フラグをチェック
        if (_deletedMlsGroupListIds.contains(list.id)) {
          AppLogger.debug('🚫 [MLS] Filtered out locally deleted MLS group: "${list.name}"');
          continue;
        }
        
        // 2. MLS鍵の有効性をチェック
        if (publicKey != null) {
          try {
            await rust_api.mlsGetGroupInfo(
              nostrId: publicKey,
              groupId: list.id,
            );
            // 成功 = 鍵が有効
            AppLogger.debug('✅ [MLS] Valid key for group: "${list.name}"');
            filtered.add(list);
          } catch (e) {
            // 失敗 = 鍵が無効（再インストール後など）
            AppLogger.warning('🔑 [MLS] Invalid key for group: "${list.name}" (auto-removing)');
            // 自動的に削除フラグに追加
            _deletedMlsGroupListIds.add(list.id);
            await _repository.saveDeletedMlsGroupListIds(_deletedMlsGroupListIds);
          }
        } else {
          // publicKeyがない場合は保持
          filtered.add(list);
        }
        continue;
      }
      
      var isDeleted = false;
      final listCreatedAt = list.createdAt.millisecondsSinceEpoch ~/ 1000; // Unix timestamp
      
      // 1. list_idベースの削除メタデータをチェック
      if (_deletedListMetadata.containsKey(list.id)) {
        final deletionTime = _deletedListMetadata[list.id]!;
        
        // LWW比較
        if (deletionTime >= listCreatedAt) {
          isDeleted = true;
          AppLogger.debug('🗑️ [CustomLists] LWW: List deleted by listId: "${list.name}" (deletion: $deletionTime >= created: $listCreatedAt)');
        } else {
          AppLogger.debug('♻️  [CustomLists] LWW: List restored by listId: "${list.name}" (created: $listCreatedAt > deletion: $deletionTime)');
        }
      }
      
      // 2. eventIdベースの削除メタデータをチェック
      if (!isDeleted) {
        String? eventId = list.eventId;
        
        // eventIdがない場合、Rustから検索
        if (eventId == null && publicKey != null) {
          try {
            eventId = await rust_api.findPersonalListEventId(
              listId: list.id,
              publicKeyHex: publicKey,
            );
          } catch (e) {
            AppLogger.debug('ℹ️  [CustomLists] Could not find eventId for list: ${list.name} ($e)');
          }
        }
        
        if (eventId != null && _deletedEventMetadata.containsKey(eventId)) {
          final deletionTime = _deletedEventMetadata[eventId]!;
          
          // LWW比較
          if (deletionTime >= listCreatedAt) {
            isDeleted = true;
            AppLogger.debug('🗑️ [CustomLists] LWW: List deleted by eventId: "${list.name}" (deletion: $deletionTime >= created: $listCreatedAt)');
          } else {
            AppLogger.debug('♻️  [CustomLists] LWW: List restored by eventId: "${list.name}" (created: $listCreatedAt > deletion: $deletionTime)');
          }
        }
      }
      
      if (!isDeleted) {
        filtered.add(list);
      }
    }
    
    if (filtered.length < lists.length) {
      AppLogger.info('🗑️ [CustomLists] Filtered out ${lists.length - filtered.length} deleted lists');
    }
    
    return filtered;
  }
  
  /// Nostrから同期されたカスタムリストを反映（LWW対応）
  /// リストメタデータ（listId, listName, eventId, created_at）を受け取り、LWW比較して反映
  Future<void> syncListsFromNostr(List<(String, String, String, int)> nostrListMetadata) async {
    // Issue #80: 最初に削除イベントを同期
    await syncDeletionEvents();
    
    AppLogger.info(' [CustomLists] 🔄 syncListsFromNostr called with ${nostrListMetadata.length} lists from Nostr (LWW)');
    AppLogger.info(' [CustomLists] 📋 Nostr lists: ${nostrListMetadata.map((m) => m.$2).join(", ")}');
    
    final currentState = state;
    AppLogger.debug(' [CustomLists] Current state type: ${currentState.runtimeType}');
    
    // 現在のリストを取得
    List<CustomList> currentLists;
    var needsStateUpdate = false; // stateの更新が必要かどうか
    
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
    var hasChanges = false;
    
    for (final (listId, listName, eventId, createdAt) in nostrListMetadata) {
      AppLogger.debug(' [CustomLists] Processing Nostr list: "$listName" (ID: $listId, created_at: $createdAt)');
      
      // LWW比較: 削除イベントをチェック
      bool isDeletedByEvent = false;
      bool isDeletedByListId = false;
      
      // 1. eventIdベースの削除チェック
      if (_deletedEventMetadata.containsKey(eventId)) {
        final deletionTime = _deletedEventMetadata[eventId]!;
        if (deletionTime >= createdAt) {
          // 削除の方が新しいorequal → スキップ
          AppLogger.info('🗑️  [CustomLists] LWW: Deletion is newer/equal, skipping list "$listName" (deletion: $deletionTime >= created: $createdAt)');
          isDeletedByEvent = true;
        } else {
          // 作成の方が新しい → 削除メタデータを無効化
          AppLogger.info('♻️  [CustomLists] LWW: Creation is newer, restoring list "$listName" (created: $createdAt > deletion: $deletionTime)');
          _deletedEventMetadata.remove(eventId);
          await _repository.saveDeletedEventMetadata(_deletedEventMetadata);
        }
      }
      
      // 2. listIdベースの削除チェック
      if (!isDeletedByEvent && _deletedListMetadata.containsKey(listId)) {
        final deletionTime = _deletedListMetadata[listId]!;
        if (deletionTime >= createdAt) {
          // 削除の方が新しいorequal → スキップ
          AppLogger.info('🗑️  [CustomLists] [Issue#101] LWW: Deletion is newer/equal, skipping list "$listName" (deletion: $deletionTime >= created: $createdAt)');
          isDeletedByListId = true;
        } else {
          // 作成の方が新しい → 削除メタデータを無効化
          AppLogger.info('♻️  [CustomLists] [Issue#101] LWW: Creation is newer, restoring list "$listName" (created: $createdAt > deletion: $deletionTime)');
          _deletedListMetadata.remove(listId);
          await _repository.saveDeletedListMetadata(_deletedListMetadata);
        }
      }
      
      // 削除されている場合はスキップ
      if (isDeletedByEvent || isDeletedByListId) {
        continue;
      }
      
      // 3. MLSグループリストのローカル削除フラグをチェック
      if (_deletedMlsGroupListIds.contains(listId)) {
        AppLogger.info('🚫 [MLS] Skipping locally deleted MLS group list: "$listName" (ID: $listId)');
        continue;
      }
      
      // すでに存在するか確認（IDで）
      final existsIndex = updatedLists.indexWhere((list) => list.id == listId);
      
      if (existsIndex == -1) {
        AppLogger.info(' [CustomLists] ✨ Adding NEW list from Nostr: "$listName" (ID: $listId)');
        
        final newList = CustomList(
          id: listId,
          name: listName.toUpperCase(),
          order: _getNextOrder(updatedLists),
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000), // Nostrのcreated_at
          updatedAt: DateTime.now(),
          eventId: eventId, // eventIdも保存
        );
        
        updatedLists.add(newList);
        hasChanges = true;
      } else {
        // 既存リストのeventIdを更新（最新のeventIdを保持）
        final existingList = updatedLists[existsIndex];
        if (existingList.eventId != eventId) {
          updatedLists[existsIndex] = existingList.copyWith(eventId: eventId);
          hasChanges = true;
          AppLogger.debug(' [CustomLists] 🔄 Updated eventId for "$listName"');
        } else {
          AppLogger.debug(' [CustomLists] ⏭️  List "$listName" (ID: $listId) already exists, skipping');
        }
      }
    }
    
    AppLogger.info(' [CustomLists] 📊 Sync result: hasChanges=$hasChanges, updatedListsCount=${updatedLists.length}, needsStateUpdate=$needsStateUpdate');
    
    // Issue #80: 削除済みリストをフィルタリング
    final filteredLists = await _filterDeletedLists(updatedLists);
    
    // Issue #101: フィルタリングでリストが削除された場合、hasChangesをtrueにする
    if (filteredLists.length < updatedLists.length) {
      hasChanges = true;
      AppLogger.info(' [CustomLists] 🗑️  ${updatedLists.length - filteredLists.length} deleted lists filtered, setting hasChanges=true');
    }
    
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
        AppLogger.info(' [CustomLists] ✅ Synced ${nostrListMetadata.length} lists from Nostr (added ${updatedLists.length - currentLists.length} new)');
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
          var hasChanges = false;
          
          for (final invitation in invitations) {
            // MLS: ローカル削除フラグをチェック
            if (_deletedMlsGroupListIds.contains(invitation.groupId)) {
              AppLogger.info('🚫 [MLS] Skipping deleted MLS group invitation: ${invitation.groupName}');
              continue;
            }
            
            // MLS: 鍵の有効性をチェック（再インストール後の無効なグループを自動削除）
            try {
              await rust_api.mlsGetGroupInfo(
                nostrId: userPubkey,
                groupId: invitation.groupId,
              );
              AppLogger.debug('✅ [MLS] Valid key for group: ${invitation.groupName}');
            } catch (e) {
              AppLogger.warning('🔑 [MLS] Invalid key for group: ${invitation.groupName}, auto-removing');
              _deletedMlsGroupListIds.add(invitation.groupId);
              await _repository.saveDeletedMlsGroupListIds(_deletedMlsGroupListIds);
              continue;
            }
            
            // 既にこのグループのリストが存在するか確認
            final existingIndex = updatedLists.indexWhere((list) => list.id == invitation.groupId);
            
            if (existingIndex == -1) {
              // 新しい招待として追加
              AppLogger.info('📨 [GroupInvitations] New invitation: ${invitation.groupName} from ${invitation.inviterPubkey.substring(0, 16)}...');
              
              // Phase 1: リレーのcreated_atを使用（冪等性確保）
              final newList = CustomList(
                id: invitation.groupId,
                name: invitation.groupName.toUpperCase(),
                order: _getNextOrder(updatedLists),
                createdAt: invitation.createdAt,  // ✅ リレーのタイムスタンプ
                updatedAt: invitation.createdAt,  // ✅ リレーのタイムスタンプ
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
              // Phase 1: 既存のリストを更新（リレーの最新情報でマージ）
              final existingList = updatedLists[existingIndex];
              
              // MLS: 削除済みリストはマージをスキップ（ユーザーが削除した後の再同期）
              if (_deletedMlsGroupListIds.contains(invitation.groupId)) {
                AppLogger.info('🚫 [MLS] Skipping merge for deleted MLS group: ${invitation.groupName}');
                // 既存のリストも削除
                updatedLists.removeAt(existingIndex);
                hasChanges = true;
                continue;
              }
              
              AppLogger.debug('🔄 [GroupInvitations] Merging invitation for existing list: ${invitation.groupName}');
              AppLogger.debug('   Existing acceptedAt: ${existingList.acceptedAt}');
              AppLogger.debug('   Existing isPendingInvitation: ${existingList.isPendingInvitation}');
              AppLogger.debug('   Relay createdAt: ${invitation.createdAt}');
              
              // Phase 1: リレーの情報で更新（acceptedAtは維持）
              // - createdAt: リレーの時刻で統一（後方互換性のため）
              // - updatedAt: リレーの最新時刻
              // - welcomeMsg: 最新のWelcome Message（Key Package更新対応）
              // - acceptedAt: 維持（承諾状態を保持）
              // - isPendingInvitation: acceptedAtの有無で判定
              updatedLists[existingIndex] = existingList.copyWith(
                name: invitation.groupName.toUpperCase(),  // グループ名が変わっているかも
                createdAt: invitation.createdAt,  // ✅ リレーの時刻で統一
                updatedAt: invitation.createdAt,  // ✅ 最新の更新時刻
                isGroup: true,
                inviterNpub: invitation.inviterPubkey,
                inviterName: invitation.inviterName,
                welcomeMsg: invitation.welcomeMessage,  // ✅ 最新のWelcome Message
                // ⚠️ acceptedAt は copyWith で渡さないため維持される
                // ⚠️ isPendingInvitation も copyWith で渡さないため維持される
              );
              hasChanges = true;
              
              AppLogger.info('✅ [GroupInvitations] Updated list from relay: ${invitation.groupName}');
              AppLogger.debug('   acceptedAt preserved: ${updatedLists[existingIndex].acceptedAt}');
              AppLogger.debug('   isPendingInvitation preserved: ${updatedLists[existingIndex].isPendingInvitation}');
            }
          }

          // 🧹 0xChatでも起きた「フォーク」対策:
          // 同名の個人リスト（名前から生成したID）がある場合、招待/グループ側を正としてシャドーを除去。
          // ただし eventId がある＝リレー同期済みの個人リストは勝手に消さない。
          final normalizedGroupNames = updatedLists
              .where((l) => l.isGroup || l.isPendingInvitation)
              .map((l) => l.name.trim().toUpperCase())
              .toSet();
          final before = updatedLists.length;
          updatedLists.removeWhere((l) {
            if (l.isGroup || l.isPendingInvitation) return false;
            if (l.eventId != null) return false;
            final normalizedName = l.name.trim().toUpperCase();
            if (!normalizedGroupNames.contains(normalizedName)) return false;
            final shadowId = CustomListHelpers.generateIdFromName(normalizedName);
            return l.id == shadowId;
          });
          if (updatedLists.length != before) {
            AppLogger.warning('🧹 [GroupInvitations] Removed ${before - updatedLists.length} shadow personal lists (fork prevention)');
            hasChanges = true;
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
        final listMap = <String, CustomList>{for (final list in lists) list.id: list};
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
      final lists = state.whenData((lists) => lists).value ?? [];
      
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
      final lists = state.whenData((lists) => lists).value ?? [];
      
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
      
      final welcomeMsgBase64 = await groupResult.fold(
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
      
      var successCount = 0;
      var failCount = 0;
      
      // Phase D.5: SendGroupInvitationUseCaseを使用
      final sendInvitationUseCase = _ref.read(mls_usecase.sendGroupInvitationUseCaseProvider);
      
      for (var i = 0; i < memberNpubs.length; i++) {
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
    // 🔥 Phase 8.7: Bug #2修正 - state.whenData() → valueOrNull に変更
    final lists = state.valueOrNull;
    if (lists == null) {
      AppLogger.warning('⚠️ [CustomLists] CustomListsProvider state is null, cannot add member to group list.');
      return;
    }

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
  }
  
  /// グループリストからメンバーを削除
  Future<void> removeMemberFromGroupList({
    required String groupId,
    required String memberPubkey,
  }) async {
    // 🔥 Phase 8.7: Bug #2修正 - state.whenData() → valueOrNull に変更
    final lists = state.valueOrNull;
    if (lists == null) {
      AppLogger.warning('⚠️ [CustomLists] CustomListsProvider state is null, cannot remove member from group list.');
      return;
    }

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
      final filteredLists = await _filterDeletedLists(updatedLists);
      
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
  /// 3. Issue #101: エラー時もロールバックしない（ローカル削除済み、タスクも削除済み）
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
      
      // 3. Issue #101: Nostr削除の成否に関わらず、削除済みイベントIDを記録
      //    ロールバックは行わない（ローカル削除は既に成功、タスクも削除済み）
      await result.fold(
        (failure) async {
          AppLogger.error('❌ [CustomLists] Failed to delete from Nostr: ${failure.message}');
          AppLogger.warning('⚠️  [CustomLists] Nostr deletion failed, but local deletion was successful');
          AppLogger.info('ℹ️  [CustomLists] List will not be restored (tasks already deleted)');
          
          // Issue #101: ロールバックしない代わりに、削除メタデータに追加して復活を防ぐ（LWW対応）
          // Nostr削除は失敗したが、ローカルでは削除済みとして扱う
          final deletionTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          _deletedEventMetadata[eventId] = deletionTime;
          final saveResult = await _repository.saveDeletedEventMetadata(_deletedEventMetadata);
          saveResult.fold(
            (Failure saveFailure) => AppLogger.warning('⚠️  [CustomLists] Failed to save deleted event metadata: ${saveFailure.message}'),
            (_) => AppLogger.info('💾 [CustomLists] Added to deletion metadata despite Nostr failure (total: ${_deletedEventMetadata.length})'),
          );
        },
        (_) async {
          AppLogger.info('✅ [CustomLists] Successfully deleted personal list from Nostr: ${targetList.name}');
          
          // 🔥 Phase 8.7: Bug #2修正 - 削除済みイベントメタデータを記録（LWW対応）
          final deletionTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          _deletedEventMetadata[eventId] = deletionTime;
          final saveResult = await _repository.saveDeletedEventMetadata(_deletedEventMetadata);
          saveResult.fold(
            (Failure failure) => AppLogger.warning('⚠️  [CustomLists] Failed to save deleted event metadata: ${failure.message}'),
            (_) => AppLogger.debug('💾 [CustomLists] Saved deleted event metadata (total: ${_deletedEventMetadata.length})'),
          );
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
  
  /// Issue #102 (MLS Zombie Lists): 承認済みMLSグループの復元
  /// 
  /// アプリ再インストール後、MLSローカルステート（openmls DB）が消失するため、
  /// Welcome Messageを再処理してグループに再参加する。
  /// 
  /// 実行タイミング: アプリ起動時（_initialize内のFuture.microtaskから）
  /// 
  /// 動作:
  /// 1. 承認済みMLSグループを検出（acceptedAt != null && isGroup == true && welcomeMsg != null）
  /// 2. 各グループのWelcome Messageを再処理（mlsJoinGroup）
  /// 3. エラーが発生した場合も、他のグループの復元を続行
  /// 
  /// ⚠️ 既知の問題 (2026-01-02):
  /// アプリ再インストール時に新しいKey Packageが生成されるため、
  /// 古いKey Packageで作成されたWelcome Messageは復号化できない。
  /// このため、現状この自動復元機能は動作しない。
  /// 
  /// 対策として、ユーザーは「辞退」ボタンで不要な招待を削除できる。
  /// 将来的な解決策: Key Packageの永続化、またはグループ管理者による再招待フロー。
  /// 
  /// Note: Oracleの要件より、リレーが同じであれば必ず復元できる必要がある。
  /// Key Packageのハンドリングが失敗している場合は許容されるが、
  /// 正常なケースでは100%復元できなければならない。
  Future<void> _restoreMlsGroupStates() async {
    try {
      AppLogger.info('🔄 [MLSRestore] Starting MLS group state restoration...');
      
      // 1. 現在のリストを取得
      final lists = state.valueOrNull;
      if (lists == null || lists.isEmpty) {
        AppLogger.debug('🔄 [MLSRestore] No lists found, skipping restoration');
        return;
      }
      
      // 2. 承認済みMLSグループを検出
      final acceptedMlsGroups = lists.where((list) =>
        list.isGroup &&
        list.acceptedAt != null &&
        list.welcomeMsg != null &&
        list.welcomeMsg!.isNotEmpty
      ).toList();
      
      if (acceptedMlsGroups.isEmpty) {
        AppLogger.info('🔄 [MLSRestore] No accepted MLS groups found, skipping restoration');
        return;
      }
      
      AppLogger.info('🔄 [MLSRestore] Found ${acceptedMlsGroups.length} accepted MLS group(s) to restore');
      
      // 3. ユーザー公開鍵を取得
      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        AppLogger.warning('🔄 [MLSRestore] User pubkey not available, cannot restore MLS groups');
        return;
      }
      
      // 4. MLS Repository経由でWelcome Messageを再処理
      final mlsRepository = _ref.read(mls_repo.mlsGroupRepositoryProvider);
      
      var successCount = 0;
      var skipCount = 0;
      var errorCount = 0;
      
      for (final group in acceptedMlsGroups) {
        try {
          AppLogger.info('🔄 [MLSRestore] Restoring MLS group: "${group.name}" (ID: ${group.id})');
          
          // Welcome Message再処理（グループに再参加）
          final result = await mlsRepository.acceptGroupInvitation(
            publicKey: userPubkey,
            groupId: group.id,
            welcomeMessage: group.welcomeMsg!,
          );
          
          await result.fold(
            (Failure failure) async {
              // エラーが発生した場合
              // Note: "already exists"系のエラーは正常（既に復元済み）
              final errorMsg = failure.message.toLowerCase();
              if (errorMsg.contains('already') || 
                  errorMsg.contains('exists') ||
                  errorMsg.contains('duplicate')) {
                AppLogger.info('✅ [MLSRestore] Group "${group.name}" already exists (previously restored)');
                skipCount++;
              } else {
                AppLogger.error('❌ [MLSRestore] Failed to restore group "${group.name}": ${failure.message}');
                errorCount++;
              }
            },
            (_) async {
              AppLogger.info('✅ [MLSRestore] Successfully restored MLS group: "${group.name}"');
              successCount++;
            },
          );
          
        } catch (e, st) {
          AppLogger.error(
            '❌ [MLSRestore] Unexpected error restoring group "${group.name}": $e',
            error: e,
            stackTrace: st,
          );
          errorCount++;
          // エラーが発生しても、次のグループの復元を続行
        }
      }
      
      // 5. 復元結果をログ出力
      AppLogger.info('🎉 [MLSRestore] MLS group restoration completed:');
      AppLogger.info('   - Total groups: ${acceptedMlsGroups.length}');
      AppLogger.info('   - Successfully restored: $successCount');
      AppLogger.info('   - Already existed (skipped): $skipCount');
      AppLogger.info('   - Errors: $errorCount');
      
      if (errorCount > 0) {
        AppLogger.warning('⚠️  [MLSRestore] Some groups could not be restored. This may indicate:');
        AppLogger.warning('   1. Key Package handling issues (acceptable)');
        AppLogger.warning('   2. Relay synchronization issues (acceptable)');
        AppLogger.warning('   3. Corrupted Welcome Messages (needs investigation)');
      }
      
    } catch (e, st) {
      AppLogger.error(
        '❌ [MLSRestore] Unexpected error during MLS group restoration: $e',
        error: e,
        stackTrace: st,
      );
      // 復元失敗してもアプリは継続（ユーザーは手動で再招待可能）
    }
  }
}

