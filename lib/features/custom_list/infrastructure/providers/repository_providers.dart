import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/local_storage_service.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../repositories/custom_list_repository_impl.dart';

/// CustomListRepository Provider
/// 
/// Phase C.3.1: LocalStorageServiceのみ依存
/// Phase C.3.2: NostrService, AmberServiceを追加予定
final customListRepositoryProvider = Provider<CustomListRepository>((ref) {
  return CustomListRepositoryImpl(
    localStorageService: localStorageService,
    // Phase C.3.2で追加:
    // nostrService: ref.watch(nostrServiceProvider),
    // amberService: ref.watch(amberServiceProvider),
  );
});

