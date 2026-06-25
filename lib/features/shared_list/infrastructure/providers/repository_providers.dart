import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/nostr_provider.dart';
import '../../../../services/local_storage_service.dart';
import '../../domain/repositories/shared_list_repository.dart';
import '../datasources/shared_group_key_local_datasource.dart';
import '../repositories/shared_list_repository_impl.dart';

final sharedGroupKeyLocalDataSourceProvider =
    Provider<SharedGroupKeyLocalDataSource>((ref) {
  return SharedGroupKeyLocalDataSource(localStorageService);
});

final sharedListRepositoryProvider = Provider<SharedListRepository>((ref) {
  return SharedListRepositoryImpl(
    keyDataSource: ref.watch(sharedGroupKeyLocalDataSourceProvider),
    nostrService: ref.watch(nostrServiceProvider),
    isAmberMode: ref.watch(isAmberModeProvider),
  );
});
