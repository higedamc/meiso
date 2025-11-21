import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/providers/repository_providers.dart';
import '../usecases/delete_personal_list_usecase.dart';

/// CustomList UseCases Provider
/// 
/// Phase E.2: Personal List削除UseCase

/// DeletePersonalListUseCase Provider
/// 
/// Phase E.2: Personal Listのリモート削除機能
/// - Kind 5削除イベントをNostrに送信
/// - グループリスト削除は不可（エラー返却）
/// - eventIdが必須
final deletePersonalListUseCaseProvider = Provider<DeletePersonalListUseCase>((ref) {
  final repository = ref.watch(customListRepositoryProvider);
  return DeletePersonalListUseCase(repository);
});

