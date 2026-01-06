import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/custom_list.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';
import '../../../../services/amber_service.dart';
import '../../../../providers/nostr_provider.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../../domain/errors/custom_list_errors.dart';
import '../../../../bridge_generated.dart/api.dart' as rust_api;
import '../../../../utils/error_handler.dart';

/// CustomListRepository実装
/// 
/// Phase C.3.1: ローカルCRUD実装済み
/// Phase C.3.2.1: 削除イベント同期実装
/// Phase C.3.2.2: カスタムリストNostr送信実装予定
/// Phase D: MLS機能を追加予定
/// 
/// 依存関係:
/// - LocalStorageService: ローカル永続化
/// - NostrService: Nostr通信（Phase C.3.2で追加）
/// - AmberService: Amber署名/復号化（Phase Eで追加）
class CustomListRepositoryImpl implements CustomListRepository {
  
  const CustomListRepositoryImpl({
    required LocalStorageService localStorageService,
    required NostrService nostrService,
    required AmberService amberService,
  }) : _localStorageService = localStorageService,
       _nostrService = nostrService,
       _amberService = amberService;
  final LocalStorageService _localStorageService;
  final NostrService _nostrService;
  // Phase E.2/E.3で使用予定
  // ignore: unused_field
  final AmberService _amberService;
  
  // ============================================================
  // ローカルストレージ操作
  // ============================================================
  
  @override
  Future<Either<Failure, List<CustomList>>> loadCustomListsFromLocal() async {
    try {
      AppLogger.debug('📂 [CustomListRepo] Loading custom lists from local storage...');
      
      final lists = await _localStorageService.loadCustomLists();
      
      AppLogger.info('✅ [CustomListRepo] Loaded ${lists.length} custom lists from local');
      return Right(lists);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to load custom lists from local',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('ローカルからカスタムリストの読み込みに失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveCustomListsToLocal(List<CustomList> lists) async {
    try {
      AppLogger.debug('💾 [CustomListRepo] Saving ${lists.length} custom lists to local storage...');
      
      await _localStorageService.saveCustomLists(lists);
      
      AppLogger.info('✅ [CustomListRepo] Saved ${lists.length} custom lists to local');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to save custom lists to local',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('ローカルへカスタムリストの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveCustomListToLocal(CustomList list) async {
    try {
      AppLogger.debug('💾 [CustomListRepo] Saving single custom list to local storage: ${list.id}');
      
      // 全リストを読み込み
      final listsResult = await loadCustomListsFromLocal();
      
      return listsResult.fold(
        Left.new,
        (lists) async {
          // 既存リストを更新 or 新規追加
          final existingIndex = lists.indexWhere((l) => l.id == list.id);
          
          List<CustomList> updatedLists;
          if (existingIndex != -1) {
            // 既存リストを更新
            updatedLists = [...lists];
            updatedLists[existingIndex] = list;
            AppLogger.debug('🔄 [CustomListRepo] Updated existing list: ${list.id}');
          } else {
            // 新規リストを追加
            updatedLists = [...lists, list];
            AppLogger.debug('✨ [CustomListRepo] Added new list: ${list.id}');
          }
          
          // 全リストを保存
          return saveCustomListsToLocal(updatedLists);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to save custom list to local',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('ローカルへカスタムリストの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteCustomListFromLocal(String id) async {
    try {
      AppLogger.debug('🗑️ [CustomListRepo] Deleting custom list from local storage: $id');
      
      // 全リストを読み込み
      final listsResult = await loadCustomListsFromLocal();
      
      return listsResult.fold(
        Left.new,
        (lists) async {
          // 指定IDのリストを削除
          final updatedLists = lists.where((l) => l.id != id).toList();
          
          if (updatedLists.length == lists.length) {
            AppLogger.warning('⚠️ [CustomListRepo] List not found: $id');
            return Left(CustomListFailure.fromError(CustomListError.notFound));
          }
          
          AppLogger.debug('✅ [CustomListRepo] Deleted list $id from local');
          
          // 全リストを保存
          return saveCustomListsToLocal(updatedLists);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to delete custom list from local',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('ローカルからカスタムリストの削除に失敗しました: $e'));
    }
  }
  
  // ============================================================
  // Nostr同期操作（Phase C.3.2.2で実装）
  // ============================================================
  
  @override
  Future<Either<Failure, List<(String, String, String, int)>>> fetchCustomListMetadataFromNostr({
    required String publicKey,
  }) async {
    try {
      AppLogger.info('📋 [CustomListRepo] Fetching custom list metadata from Nostr (LWW)...');
      
      // Phase 8.5.2: 軽量APIを使用（contentを取得しない、created_at含む）
      final listNamesData = await ErrorHandler.withTimeout<List<rust_api.TodoListName>>(
        operation: () => rust_api.fetchTodoListNamesOnly(publicKeyHex: publicKey),
        operationName: 'fetchTodoListNamesOnly',
        timeout: const Duration(seconds: 5),
        defaultValue: <rust_api.TodoListName>[],
      );
      
      if (listNamesData.isEmpty) {
        AppLogger.debug('📋 [CustomListRepo] No lists found, returning empty list');
        return const Right([]);
      }
      
      // LWW対応: メタデータ（listId, listName, eventId, created_at）を返す
      final listMetadata = <(String, String, String, int)>[];
      for (final data in listNamesData) {
        // list_idから名前ベースIDを抽出（meiso-list-プレフィックスを削除）
        String nameBasedId;
        if (data.listId.startsWith('meiso-list-')) {
          nameBasedId = data.listId.substring('meiso-list-'.length);
        } else {
          nameBasedId = data.listId;
        }
        
        String listName;
        
        // titleタグがあればそれを使用
        if (data.title != null && data.title!.isNotEmpty) {
          listName = data.title!;
        } else if (data.listId.startsWith('meiso-list-')) {
          // titleがない場合、list_idから名前を抽出
          listName = data.listId.substring('meiso-list-'.length);
        } else {
          listName = data.listId;
        }
        
        // (listId, listName, eventId, created_at) を追加
        // BigInt → int 変換
        listMetadata.add((nameBasedId, listName, data.eventId, data.createdAt.toInt()));
      }
      
      AppLogger.info('✅ [CustomListRepo] Fetched ${listMetadata.length} list metadata');
      return Right(listMetadata);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to fetch custom list metadata',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListNetworkFailure('カスタムリストメタデータの取得に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<CustomList>>> syncPersonalListsFromNostr() async {
    return const Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, void>> syncPersonalListsToNostr({
    required List<CustomList> lists,
    required bool isAmberMode,
  }) async {
    return const Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, Map<String, int>>> syncDeletionEvents({
    required String publicKey,
  }) async {
    try {
      AppLogger.info('🗑️ [CustomListRepo] Syncing deletion events (kind 5) with LWW...');
      
      // Rust APIを呼び出してkind 5削除イベントを取得（タイムスタンプ付き）
      final deletedEvents = await rust_api.fetchDeletionEventsForPubkeyWithClientId(
        publicKeyHex: publicKey,
      );
      
      // Vec<(String, u64)> を Map<String, int> に変換
      final Map<String, int> metadata = {};
      for (final (eventId, createdAt) in deletedEvents) {
        // BigInt → int 変換
        metadata[eventId] = createdAt.toInt();
      }
      
      if (metadata.isNotEmpty) {
        AppLogger.info('✅ [CustomListRepo] Synced ${metadata.length} deletion events with timestamps');
        return Right(metadata);
      } else {
        AppLogger.info('ℹ️ [CustomListRepo] No deletion events found');
        return const Right(<String, int>{});
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to sync deletion events',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListNetworkFailure('削除イベントの同期に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveDeletedEventMetadata(Map<String, int> metadata) async {
    try {
      AppLogger.debug('💾 [CustomListRepo] Saving ${metadata.length} deleted event metadata...');
      
      await _localStorageService.saveDeletedEventMetadata(metadata);
      
      AppLogger.info('✅ [CustomListRepo] Saved ${metadata.length} deleted event metadata');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to save deleted event metadata',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除イベントメタデータの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, Map<String, int>>> loadDeletedEventMetadata() async {
    try {
      AppLogger.debug('📂 [CustomListRepo] Loading deleted event metadata...');
      
      final metadata = await _localStorageService.loadDeletedEventMetadata();
      
      AppLogger.info('✅ [CustomListRepo] Loaded ${metadata.length} deleted event metadata');
      return Right(metadata);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to load deleted event metadata',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除イベントメタデータの読み込みに失敗しました: $e'));
    }
  }
  
  // ============================================================
  // 削除済みリストID管理（Issue #101、LWW対応）
  // ============================================================
  
  @override
  Future<Either<Failure, void>> saveDeletedListMetadata(Map<String, int> metadata) async {
    try {
      AppLogger.debug('💾 [CustomListRepo] Saving ${metadata.length} deleted list metadata...');
      
      await _localStorageService.saveDeletedListMetadata(metadata);
      
      AppLogger.info('✅ [CustomListRepo] Saved ${metadata.length} deleted list metadata');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to save deleted list metadata',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除リストメタデータの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, Map<String, int>>> loadDeletedListMetadata() async {
    try {
      AppLogger.debug('📂 [CustomListRepo] Loading deleted list metadata...');
      
      final metadata = await _localStorageService.loadDeletedListMetadata();
      
      AppLogger.info('✅ [CustomListRepo] Loaded ${metadata.length} deleted list metadata');
      return Right(metadata);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to load deleted list IDs',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除リストIDの読み込みに失敗しました: $e'));
    }
  }
  
  // ============================================================
  // MLSグループリスト削除管理
  // ============================================================
  
  @override
  Future<Either<Failure, void>> saveDeletedMlsGroupListIds(Set<String> ids) async {
    try {
      AppLogger.debug('💾 [CustomListRepo] Saving ${ids.length} deleted MLS group list IDs...');
      
      await _localStorageService.saveDeletedMlsGroupListIds(ids);
      
      AppLogger.info('✅ [CustomListRepo] Saved deleted MLS group list IDs');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to save deleted MLS group list IDs',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除MLSグループリストIDの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, Set<String>>> loadDeletedMlsGroupListIds() async {
    try {
      AppLogger.debug('📂 [CustomListRepo] Loading deleted MLS group list IDs...');
      
      final ids = await _localStorageService.loadDeletedMlsGroupListIds();
      
      AppLogger.info('✅ [CustomListRepo] Loaded ${ids.length} deleted MLS group list IDs');
      return Right(ids);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to load deleted MLS group list IDs',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除MLSグループリストIDの読み込みに失敗しました: $e'));
    }
  }
  
  // ============================================================
  // MLS操作（Phase Dで実装予定）
  // ============================================================
  
  @override
  Future<Either<Failure, CustomList>> createMlsGroup({
    required String groupId,
    required String groupName,
    required List<String> keyPackages,
  }) async {
    return const Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  // ============================================================
  // Personal List削除・更新（Phase E）
  // ============================================================
  
  @override
  Future<Either<Failure, void>> deletePersonalListFromNostr({
    required String listId,
    required String eventId,
    required bool isAmberMode,
  }) async {
    try {
      AppLogger.info('🗑️  [CustomListRepo] Deleting personal list from Nostr: $listId (eventId: ${eventId.substring(0, 16)}...)');
      
      // Kind 5削除イベントをNostrServiceで送信
      // （NostrService.deleteEvents()がAmber/秘密鍵モードを自動判定）
      final sendResult = await _nostrService.deleteEvents(
        [eventId],
        reason: 'Deleted by user',
      );
      
      // Issue #101: 削除済みイベントIDの保存はProvider側で行う（重複を避ける）
      // Provider側の_deletedEventIdsメモリ変数と同期するため
      
      AppLogger.info('✅ [CustomListRepo] Successfully deleted personal list: $listId (deletion event: ${sendResult.eventId.substring(0, 16)}...)');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to delete personal list',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListNetworkFailure('リストの削除に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, String>> updatePersonalListToNostr({
    required CustomList list,
    required bool isAmberMode,
  }) async {
    // Phase E.2で実装予定
    // TODO: 空のTODOリストイベント（Kind 30001）を送信してリスト名・orderを更新
    return const Left(UnexpectedFailure('Not implemented yet - Phase E.2'));
  }
  
  @override
  Future<Either<Failure, String>> publishEmptyPersonalList({
    required CustomList list,
    required bool isAmberMode,
  }) async {
    // Phase E.3で実装予定
    // TODO: 空のTODOリストイベント（Kind 30001）を送信して空リストを同期
    return const Left(UnexpectedFailure('Not implemented yet - Phase E.3'));
  }
  
  // ============================================================
  // MLS操作（Phase D）
  // ============================================================
  
  @override
  Future<Either<Failure, List<CustomList>>> syncGroupInvitations({
    required String recipientPublicKey,
  }) async {
    return const Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, void>> addMemberToGroup({
    required String groupId,
    required String memberPubkey,
  }) async {
    return const Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, void>> removeMemberFromGroup({
    required String groupId,
    required String memberPubkey,
  }) async {
    return const Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
}

