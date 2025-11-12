import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/custom_list.dart';

/// カスタムリストのリポジトリインターフェース
///
/// データの永続化とビジネスロジックの間の抽象化層
abstract class CustomListRepository {
  /// 全てのカスタムリストを取得
  Future<Either<Failure, List<CustomList>>> getAllCustomLists();
  
  /// IDでカスタムリストを取得
  Future<Either<Failure, CustomList>> getCustomListById(String id);
  
  /// カスタムリストを作成
  Future<Either<Failure, CustomList>> createCustomList(CustomList customList);
  
  /// カスタムリストを更新
  Future<Either<Failure, CustomList>> updateCustomList(CustomList customList);
  
  /// カスタムリストを削除
  Future<Either<Failure, void>> deleteCustomList(String id);
  
  /// カスタムリストを並び替え
  /// 
  /// [lists] 新しい順番のリスト
  Future<Either<Failure, List<CustomList>>> reorderCustomLists(
    List<CustomList> lists,
  );
  
  /// Nostrから同期されたリスト名を処理
  /// 
  /// [nostrListNames] Nostrから取得したリスト名のリスト
  /// 既存のリストにないものを追加
  Future<Either<Failure, List<CustomList>>> syncFromNostr(
    List<String> nostrListNames,
  );
  
  /// デフォルトリストを作成（リストが空の場合のみ）
  Future<Either<Failure, List<CustomList>>> createDefaultListsIfEmpty();
}

