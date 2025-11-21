import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../../../models/custom_list.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../../domain/errors/custom_list_errors.dart';
import '../../../../services/logger_service.dart';

/// Personal List削除UseCase
/// 
/// Phase E.2: Personal Listのリモート削除機能
/// 
/// 機能:
/// 1. バリデーション: グループリスト削除不可、eventId必須
/// 2. Repository経由でKind 5削除イベント送信
/// 3. 削除済みイベントIDをローカル保存
/// 
/// 制限:
/// - Personal List（isGroup=false）のみ削除可能
/// - eventIdが必須（Nostrイベント削除用）
/// - グループリスト（isGroup=true）は削除不可（エラー返却）
class DeletePersonalListUseCase implements UseCase<void, DeletePersonalListParams> {
  final CustomListRepository _repository;
  
  const DeletePersonalListUseCase(this._repository);
  
  @override
  Future<Either<Failure, void>> call(DeletePersonalListParams params) async {
    AppLogger.info('🗑️  [UseCase] Deleting personal list: ${params.list.name} (id: ${params.list.id})');
    
    // 1. バリデーション: グループリストは削除不可
    if (params.list.isGroup) {
      AppLogger.warning('❌ [UseCase] Cannot delete group list: ${params.list.id}');
      return Left(CustomListFailure(
        CustomListError.unauthorized,
        'グループリストはこの方法で削除できません',
      ));
    }
    
    // 2. バリデーション: eventIdが必須
    if (params.eventId == null || params.eventId!.isEmpty) {
      AppLogger.warning('❌ [UseCase] Event ID is required for remote deletion: ${params.list.id}');
      return Left(CustomListFailure(
        CustomListError.notFound,
        'リモート削除にはイベントIDが必要です',
      ));
    }
    
    // 3. Repository経由で削除
    AppLogger.debug('📤 [UseCase] Calling repository.deletePersonalListFromNostr()...');
    final result = await _repository.deletePersonalListFromNostr(
      listId: params.list.id,
      eventId: params.eventId!,
      isAmberMode: params.isAmberMode,
    );
    
    return result.fold(
      (failure) {
        AppLogger.error('❌ [UseCase] Failed to delete personal list: ${failure.message}');
        return Left(failure);
      },
      (_) {
        AppLogger.info('✅ [UseCase] Successfully deleted personal list: ${params.list.name}');
        return const Right(null);
      },
    );
  }
}

/// DeletePersonalListUseCaseのパラメータ
/// 
/// Phase E.2: Personal List削除に必要なパラメータ
class DeletePersonalListParams {
  /// 削除するカスタムリスト
  final CustomList list;
  
  /// NostrイベントID（Kind 5削除イベント送信用）
  /// 
  /// Personal Listに対応するKind 30001イベントのID
  /// これをKind 5削除イベントで参照して削除する
  final String? eventId;
  
  /// Amberモードかどうか
  /// 
  /// true: Amber署名を使用
  /// false: 秘密鍵モード署名を使用
  final bool isAmberMode;
  
  const DeletePersonalListParams({
    required this.list,
    required this.eventId,
    required this.isAmberMode,
  });
}

