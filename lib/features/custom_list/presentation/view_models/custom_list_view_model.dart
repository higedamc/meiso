import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/common/usecase.dart';
import '../../../../services/logger_service.dart';
import '../../application/usecases/create_custom_list_usecase.dart';
import '../../application/usecases/delete_custom_list_usecase.dart';
import '../../application/usecases/get_all_custom_lists_usecase.dart';
import '../../application/usecases/reorder_custom_lists_usecase.dart';
import '../../application/usecases/sync_custom_lists_from_nostr_usecase.dart';
import '../../application/usecases/update_custom_list_usecase.dart';
import '../../domain/entities/custom_list.dart';
import 'custom_list_state.dart';

/// CustomListのViewModel (StateNotifier)
///
/// UseCaseを使用してCustomListの状態を管理する
class CustomListViewModel extends StateNotifier<CustomListState> {
  CustomListViewModel({
    required GetAllCustomListsUseCase getAllCustomListsUseCase,
    required CreateCustomListUseCase createCustomListUseCase,
    required UpdateCustomListUseCase updateCustomListUseCase,
    required DeleteCustomListUseCase deleteCustomListUseCase,
    required ReorderCustomListsUseCase reorderCustomListsUseCase,
    required SyncCustomListsFromNostrUseCase syncCustomListsFromNostrUseCase,
    bool autoLoad = true,
  })  : _getAllCustomListsUseCase = getAllCustomListsUseCase,
        _createCustomListUseCase = createCustomListUseCase,
        _updateCustomListUseCase = updateCustomListUseCase,
        _deleteCustomListUseCase = deleteCustomListUseCase,
        _reorderCustomListsUseCase = reorderCustomListsUseCase,
        _syncCustomListsFromNostrUseCase = syncCustomListsFromNostrUseCase,
        super(const CustomListState.initial()) {
    if (autoLoad) {
      _initialize();
    }
  }
  
  /// 初期化処理
  Future<void> _initialize() async {
    // CustomListを読み込み
    await loadCustomLists();
    
    // 空の場合はデフォルトリストを作成
    state.maybeMap(
      loaded: (loadedState) {
        if (loadedState.customLists.isEmpty) {
          AppLogger.info('[CustomListViewModel] デフォルトリスト作成中...');
          _createDefaultLists();
        }
      },
      orElse: () {},
    );
  }
  
  /// デフォルトリストを作成
  Future<void> _createDefaultLists() async {
    final defaultLists = ['PERSONAL', 'SHOPPING', 'WATCH'];
    
    for (var i = 0; i < defaultLists.length; i++) {
      await createCustomList(
        name: defaultLists[i],
        order: i,
      );
    }
    
    AppLogger.info('[CustomListViewModel] デフォルトリスト作成完了');
  }

  final GetAllCustomListsUseCase _getAllCustomListsUseCase;
  final CreateCustomListUseCase _createCustomListUseCase;
  final UpdateCustomListUseCase _updateCustomListUseCase;
  final DeleteCustomListUseCase _deleteCustomListUseCase;
  final ReorderCustomListsUseCase _reorderCustomListsUseCase;
  final SyncCustomListsFromNostrUseCase _syncCustomListsFromNostrUseCase;

  /// CustomListを読み込む
  Future<void> loadCustomLists() async {
    state = const CustomListState.loading();

    final result = await _getAllCustomListsUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[CustomListViewModel] CustomList読み込みエラー: ${failure.message}');
        state = CustomListState.error(failure);
      },
      (customLists) {
        AppLogger.info('[CustomListViewModel] ${customLists.length}件のCustomListを読み込み');
        state = CustomListState.loaded(customLists: customLists);
      },
    );
  }

  /// CustomListを作成
  Future<void> createCustomList({
    required String name,
    required int order,
  }) async {
    final params = CreateCustomListParams(
      name: name,
      order: order,
    );

    final result = await _createCustomListUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[CustomListViewModel] CustomList作成エラー: ${failure.message}');
        state = CustomListState.error(failure);
      },
      (customList) {
        AppLogger.info('[CustomListViewModel] CustomList作成成功: ${customList.name.value}');
        // 再読み込み
        loadCustomLists();
      },
    );
  }

  /// CustomListを更新
  Future<void> updateCustomList({
    required String id,
    String? name,
    int? order,
  }) async {
    final params = UpdateCustomListParams(
      id: id,
      name: name,
      order: order,
    );

    final result = await _updateCustomListUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[CustomListViewModel] CustomList更新エラー: ${failure.message}');
        state = CustomListState.error(failure);
      },
      (customList) {
        AppLogger.info('[CustomListViewModel] CustomList更新成功: ${customList.name.value}');
        // 再読み込み
        loadCustomLists();
      },
    );
  }

  /// CustomListを削除
  Future<void> deleteCustomList(String id) async {
    final result = await _deleteCustomListUseCase(id);

    result.fold(
      (failure) {
        AppLogger.error('[CustomListViewModel] CustomList削除エラー: ${failure.message}');
        state = CustomListState.error(failure);
      },
      (_) {
        AppLogger.info('[CustomListViewModel] CustomList削除成功: $id');
        // 再読み込み
        loadCustomLists();
      },
    );
  }

  /// CustomListを並び替え
  Future<void> reorderCustomLists(List<CustomList> lists) async {
    final result = await _reorderCustomListsUseCase(lists);

    result.fold(
      (failure) {
        AppLogger.error('[CustomListViewModel] CustomList並び替えエラー: ${failure.message}');
        state = CustomListState.error(failure);
      },
      (reorderedLists) {
        AppLogger.info('[CustomListViewModel] CustomList並び替え成功: ${reorderedLists.length}件');
        state = CustomListState.loaded(customLists: reorderedLists);
      },
    );
  }

  /// Nostrから同期
  Future<void> syncFromNostr(List<String> nostrListNames) async {
    final result = await _syncCustomListsFromNostrUseCase(nostrListNames);

    result.fold(
      (failure) {
        AppLogger.error('[CustomListViewModel] Nostr同期エラー: ${failure.message}');
        // エラーでも再読み込みして現在の状態を表示
        loadCustomLists();
      },
      (syncedLists) {
        AppLogger.info('[CustomListViewModel] Nostr同期成功: ${syncedLists.length}件');
        state = CustomListState.loaded(customLists: syncedLists);
      },
    );
  }
}

