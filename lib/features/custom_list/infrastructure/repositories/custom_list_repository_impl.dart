import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/custom_list.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';
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
/// - AmberService: Amber署名/復号化（Phase C.3.2.2で追加予定）
class CustomListRepositoryImpl implements CustomListRepository {
  final LocalStorageService _localStorageService;
  // Phase C.3.2.2で使用予定
  // ignore: unused_field
  final NostrService _nostrService;
  
  const CustomListRepositoryImpl({
    required LocalStorageService localStorageService,
    required NostrService nostrService,
  }) : _localStorageService = localStorageService,
       _nostrService = nostrService;
  
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
        (failure) => Left(failure),
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
        (failure) => Left(failure),
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
  Future<Either<Failure, List<String>>> fetchCustomListNamesFromNostr({
    required String publicKey,
  }) async {
    try {
      AppLogger.info('📋 [CustomListRepo] Fetching custom list names from Nostr...');
      
      // Phase 8.5.2: 軽量APIを使用（contentを取得しない）
      final listNamesData = await ErrorHandler.withTimeout<List<rust_api.TodoListName>>(
        operation: () => rust_api.fetchTodoListNamesOnly(publicKeyHex: publicKey),
        operationName: 'fetchTodoListNamesOnly',
        timeout: const Duration(seconds: 5),
        defaultValue: <rust_api.TodoListName>[],
      );
      
      if (listNamesData.isEmpty) {
        AppLogger.debug('📋 [CustomListRepo] No list names found, returning empty list');
        return const Right([]);
      }
      
      // list_idからリスト名を抽出
      final List<String> listNames = [];
      for (final data in listNamesData) {
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
        
        // 重複チェック
        if (!listNames.contains(listName)) {
          listNames.add(listName);
        }
      }
      
      AppLogger.info('✅ [CustomListRepo] Fetched ${listNames.length} custom list names');
      return Right(listNames);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to fetch custom list names',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListNetworkFailure('カスタムリスト名の取得に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<CustomList>>> syncPersonalListsFromNostr() async {
    return Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, void>> syncPersonalListsToNostr({
    required List<CustomList> lists,
    required bool isAmberMode,
  }) async {
    return Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, Set<String>>> syncDeletionEvents({
    required String publicKey,
  }) async {
    try {
      AppLogger.info('🗑️ [CustomListRepo] Syncing deletion events (kind 5)...');
      
      // Rust APIを呼び出してkind 5削除イベントを取得
      final deletedIds = await rust_api.fetchDeletionEventsForPubkeyWithClientId(
        publicKeyHex: publicKey,
        clientId: null,
      );
      
      if (deletedIds.isNotEmpty) {
        AppLogger.info('✅ [CustomListRepo] Synced ${deletedIds.length} deletion events');
        return Right(deletedIds.toSet());
      } else {
        AppLogger.info('ℹ️ [CustomListRepo] No deletion events found');
        return Right(<String>{});
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
  Future<Either<Failure, void>> saveDeletedEventIds(Set<String> eventIds) async {
    try {
      AppLogger.debug('💾 [CustomListRepo] Saving ${eventIds.length} deleted event IDs...');
      
      await _localStorageService.saveDeletedEventIds(eventIds.toList());
      
      AppLogger.info('✅ [CustomListRepo] Saved ${eventIds.length} deleted event IDs');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to save deleted event IDs',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除イベントIDの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, Set<String>>> loadDeletedEventIds() async {
    try {
      AppLogger.debug('📂 [CustomListRepo] Loading deleted event IDs...');
      
      final eventIds = await _localStorageService.loadDeletedEventIds();
      
      AppLogger.info('✅ [CustomListRepo] Loaded ${eventIds.length} deleted event IDs');
      return Right(eventIds.toSet());
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [CustomListRepo] Failed to load deleted event IDs',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(CustomListLocalStorageFailure('削除イベントIDの読み込みに失敗しました: $e'));
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
    return Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, List<CustomList>>> syncGroupInvitations({
    required String recipientPublicKey,
  }) async {
    return Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, void>> addMemberToGroup({
    required String groupId,
    required String memberPubkey,
  }) async {
    return Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
  
  @override
  Future<Either<Failure, void>> removeMemberFromGroup({
    required String groupId,
    required String memberPubkey,
  }) async {
    return Left(UnexpectedFailure('Not implemented yet - Phase D'));
  }
}

