import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../providers/nostr_provider.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../repositories/custom_list_repository_impl.dart';

/// CustomListRepository Provider
/// 
/// Phase C.3.1: LocalStorageServiceのみ依存
/// Phase C.3.2.1: NostrService追加（削除イベント同期用）
/// Phase C.3.2.2: AmberServiceを追加予定
final customListRepositoryProvider = Provider<CustomListRepository>((ref) {
  return CustomListRepositoryImpl(
    localStorageService: localStorageService,
    nostrService: ref.watch(nostrServiceProvider),
    // Phase C.3.2.2で追加予定:
    // amberService: ref.watch(amberServiceProvider),
  );
});

