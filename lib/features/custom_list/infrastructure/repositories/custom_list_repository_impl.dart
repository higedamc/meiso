import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/errors/custom_list_errors.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../../domain/value_objects/list_name.dart';
import '../datasources/custom_list_local_datasource.dart';

/// CustomListRepositoryの実装
class CustomListRepositoryImpl implements CustomListRepository {
  const CustomListRepositoryImpl({
    required this.localDataSource,
  });
  
  final CustomListLocalDataSource localDataSource;
  
  @override
  Future<Either<Failure, List<CustomList>>> getAllCustomLists() async {
    try {
      final lists = await localDataSource.getAllCustomLists();
      return Right(lists);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] getAllCustomLists failed: $e');
      return Left(CustomListError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, CustomList>> getCustomListById(String id) async {
    try {
      final lists = await localDataSource.getAllCustomLists();
      final list = lists.firstWhere(
        (l) => l.id == id,
        orElse: () => throw Exception('List not found'),
      );
      return Right(list);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] getCustomListById failed: $e');
      return Left(CustomListError.notFound.toFailure());
    }
  }
  
  @override
  Future<Either<Failure, CustomList>> createCustomList(
    CustomList customList,
  ) async {
    try {
      // 既存リストをチェック（重複防止）
      final existingLists = await localDataSource.getAllCustomLists();
      if (existingLists.any((list) => list.id == customList.id)) {
        return Left(CustomListError.duplicateName.toFailure());
      }
      
      await localDataSource.addCustomList(customList);
      AppLogger.info('✅ [CustomListRepository] Created list: ${customList.name.value}');
      return Right(customList);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] createCustomList failed: $e');
      return Left(CustomListError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, CustomList>> updateCustomList(
    CustomList customList,
  ) async {
    try {
      await localDataSource.updateCustomList(customList);
      AppLogger.info('✅ [CustomListRepository] Updated list: ${customList.name.value}');
      return Right(customList);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] updateCustomList failed: $e');
      return Left(CustomListError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteCustomList(String id) async {
    try {
      await localDataSource.deleteCustomList(id);
      AppLogger.info('✅ [CustomListRepository] Deleted list: $id');
      return const Right(null);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] deleteCustomList failed: $e');
      return Left(CustomListError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<CustomList>>> reorderCustomLists(
    List<CustomList> lists,
  ) async {
    try {
      // orderを再計算
      final reorderedLists = <CustomList>[];
      for (var i = 0; i < lists.length; i++) {
        reorderedLists.add(lists[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        ));
      }
      
      await localDataSource.saveCustomLists(reorderedLists);
      AppLogger.info('✅ [CustomListRepository] Reordered ${reorderedLists.length} lists');
      return Right(reorderedLists);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] reorderCustomLists failed: $e');
      return Left(CustomListError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<CustomList>>> syncFromNostr(
    List<String> nostrListNames,
  ) async {
    try {
      final currentLists = await localDataSource.getAllCustomLists();
      final updatedLists = List<CustomList>.from(currentLists);
      final now = DateTime.now();
      var hasChanges = false;
      
      for (final listName in nostrListNames) {
        // 名前から決定的なIDを生成
        final listId = CustomList.generateIdFromName(listName);
        
        // すでに存在するか確認（IDで）
        final exists = updatedLists.any((list) => list.id == listId);
        
        if (!exists) {
          // ListNameを作成
          final nameResult = ListName.create(listName);
          if (nameResult.isLeft()) {
            // バリデーションエラーの場合はスキップ
            AppLogger.warning('⚠️ Invalid list name from Nostr: $listName');
            continue;
          }
          
          final name = nameResult.getOrElse(() => throw Exception('Should never happen'));
          final nextOrder = updatedLists.isEmpty 
              ? 0 
              : updatedLists.map((l) => l.order).reduce((a, b) => a > b ? a : b) + 1;
          
          final newList = CustomList(
            id: listId,
            name: name,
            order: nextOrder,
            createdAt: now,
            updatedAt: now,
          );
          
          updatedLists.add(newList);
          hasChanges = true;
          
          AppLogger.debug('📥 [CustomListRepository] Added list from Nostr: "$listName" (ID: $listId)');
        }
      }
      
      if (hasChanges) {
        await localDataSource.saveCustomLists(updatedLists);
        AppLogger.info('✅ [CustomListRepository] Synced ${nostrListNames.length} lists from Nostr (added ${updatedLists.length - currentLists.length} new)');
      } else {
        AppLogger.debug('ℹ️ [CustomListRepository] No new lists to sync from Nostr');
      }
      
      return Right(updatedLists);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] syncFromNostr failed: $e');
      return Left(CustomListError.syncError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<CustomList>>> createDefaultListsIfEmpty() async {
    try {
      final currentLists = await localDataSource.getAllCustomLists();
      
      // 既にリストがある場合は何もしない
      if (currentLists.isNotEmpty) {
        AppLogger.debug('ℹ️ [CustomListRepository] Lists already exist, skipping default creation');
        return Left(CustomListError.notEmpty.toFailure());
      }
      
      AppLogger.info('📝 [CustomListRepository] Creating default lists (no lists found)');
      
      final now = DateTime.now();
      final initialListNames = [
        'BRAIN DUMP',
        'GROCERY',
        'WISHLIST',
        'NOSTR',
        'WORK',
      ];
      
      final defaultLists = <CustomList>[];
      for (var i = 0; i < initialListNames.length; i++) {
        final name = initialListNames[i];
        final nameResult = ListName.create(name);
        
        if (nameResult.isLeft()) {
          continue; // バリデーションエラーはスキップ
        }
        
        final validName = nameResult.getOrElse(() => throw Exception('Should never happen'));
        
        defaultLists.add(CustomList(
          id: CustomList.generateIdFromName(name),
          name: validName,
          order: i,
          createdAt: now,
          updatedAt: now,
        ));
      }
      
      await localDataSource.saveCustomLists(defaultLists);
      AppLogger.info('✅ [CustomListRepository] Created ${defaultLists.length} default lists');
      
      return Right(defaultLists);
    } catch (e) {
      AppLogger.error('❌ [CustomListRepository] createDefaultListsIfEmpty failed: $e');
      return Left(CustomListError.storageError.toFailure(e.toString()));
    }
  }
}

