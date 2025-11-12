import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/usecases/create_custom_list_usecase.dart';
import '../../application/usecases/delete_custom_list_usecase.dart';
import '../../application/usecases/get_all_custom_lists_usecase.dart';
import '../../application/usecases/reorder_custom_lists_usecase.dart';
import '../../application/usecases/sync_custom_lists_from_nostr_usecase.dart';
import '../../application/usecases/update_custom_list_usecase.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../../infrastructure/datasources/custom_list_local_datasource.dart';
import '../../infrastructure/repositories/custom_list_repository_impl.dart';
import '../view_models/custom_list_state.dart';
import '../view_models/custom_list_view_model.dart';

// ============================================================================
// Infrastructure層 Providers
// ============================================================================

/// CustomListLocalDataSourceのProvider
final customListLocalDataSourceProvider = Provider<CustomListLocalDataSource>((ref) {
  return CustomListLocalDataSourceHive(boxName: 'custom_lists');
});

/// CustomListRepositoryのProvider
final customListRepositoryProvider = Provider<CustomListRepository>((ref) {
  return CustomListRepositoryImpl(
    localDataSource: ref.watch(customListLocalDataSourceProvider),
  );
});

// ============================================================================
// Application層 Providers (UseCases)
// ============================================================================

final getAllCustomListsUseCaseProvider = Provider<GetAllCustomListsUseCase>((ref) {
  return GetAllCustomListsUseCase(ref.watch(customListRepositoryProvider));
});

final createCustomListUseCaseProvider = Provider<CreateCustomListUseCase>((ref) {
  return CreateCustomListUseCase(ref.watch(customListRepositoryProvider));
});

final updateCustomListUseCaseProvider = Provider<UpdateCustomListUseCase>((ref) {
  return UpdateCustomListUseCase(ref.watch(customListRepositoryProvider));
});

final deleteCustomListUseCaseProvider = Provider<DeleteCustomListUseCase>((ref) {
  return DeleteCustomListUseCase(ref.watch(customListRepositoryProvider));
});

final reorderCustomListsUseCaseProvider = Provider<ReorderCustomListsUseCase>((ref) {
  return ReorderCustomListsUseCase(ref.watch(customListRepositoryProvider));
});

final syncCustomListsFromNostrUseCaseProvider = Provider<SyncCustomListsFromNostrUseCase>((ref) {
  return SyncCustomListsFromNostrUseCase(ref.watch(customListRepositoryProvider));
});

// ============================================================================
// Presentation層 Providers (ViewModel)
// ============================================================================

final customListViewModelProvider =
    StateNotifierProvider<CustomListViewModel, CustomListState>((ref) {
  return CustomListViewModel(
    getAllCustomListsUseCase: ref.watch(getAllCustomListsUseCaseProvider),
    createCustomListUseCase: ref.watch(createCustomListUseCaseProvider),
    updateCustomListUseCase: ref.watch(updateCustomListUseCaseProvider),
    deleteCustomListUseCase: ref.watch(deleteCustomListUseCaseProvider),
    reorderCustomListsUseCase: ref.watch(reorderCustomListsUseCaseProvider),
    syncCustomListsFromNostrUseCase: ref.watch(syncCustomListsFromNostrUseCaseProvider),
  );
});

