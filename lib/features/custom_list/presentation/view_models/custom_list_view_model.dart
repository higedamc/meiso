import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/custom_list.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';
import '../../../../providers/custom_lists_provider.dart' as old;
import 'custom_list_state.dart';

/// CustomListのViewModel
class CustomListViewModel extends StateNotifier<CustomListState> {
  CustomListViewModel(
    this._ref, {
    bool autoLoad = true,
  }) : super(const CustomListState.initial()) {
    if (autoLoad) {
      _initialize();
    }
  }

  final Ref _ref;

  /// 初期化処理
  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localLists = await localStorageService.loadCustomLists();
      
      if (localLists.isEmpty) {
        AppLogger.info('[CustomListViewModel] ローカルリストなし、デフォルトリストを作成');
        state = const CustomListState.loaded(customLists: []);
        // デフォルトリストを作成
        await _createDefaultLists();
      } else {
        AppLogger.info('[CustomListViewModel] ${localLists.length}件のリストを読み込み');
        state = CustomListState.loaded(customLists: localLists);
      }
    } catch (e, stackTrace) {
      AppLogger.error('[CustomListViewModel] 初期化エラー', error: e, stackTrace: stackTrace);
      state = CustomListState.error(message: e.toString());
    }
  }

  /// デフォルトリストを作成
  Future<void> _createDefaultLists() async {
    try {
      final now = DateTime.now();
      
      final initialListNames = [
        'BRAIN DUMP',
        'GROCERY',
        'WISHLIST',
        'NOSTR',
        'WORK',
      ];
      
      final initialLists = initialListNames.asMap().entries.map((entry) {
        final index = entry.key;
        final name = entry.value;
        return CustomList(
          id: CustomListHelpers.generateIdFromName(name),
          name: name,
          order: index,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();
      
      // ローカルに保存
      await localStorageService.saveCustomLists(initialLists);
      
      // Stateを更新
      state = CustomListState.loaded(customLists: initialLists);
      
      AppLogger.info('[CustomListViewModel] ${initialLists.length}件のデフォルトリストを作成');
      
      // 旧Providerにも反映（Nostr同期のため）
      final oldNotifier = _ref.read(old.customListsProvider.notifier);
      await oldNotifier.createDefaultListsIfEmpty();
    } catch (e, stackTrace) {
      AppLogger.error('[CustomListViewModel] デフォルトリスト作成エラー', error: e, stackTrace: stackTrace);
    }
  }

  /// CustomListを読み込み
  Future<void> loadCustomLists() async {
    try {
      final localLists = await localStorageService.loadCustomLists();
      state = CustomListState.loaded(customLists: localLists);
    } catch (e, stackTrace) {
      AppLogger.error('[CustomListViewModel] リスト読み込みエラー', error: e, stackTrace: stackTrace);
      state = CustomListState.error(message: e.toString());
    }
  }
}

