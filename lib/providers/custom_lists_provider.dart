import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_list.dart';
import '../services/local_storage_service.dart';

/// カスタムリストを管理するProvider
final customListsProvider =
    StateNotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>(
  (ref) => CustomListsNotifier(),
);

class CustomListsNotifier extends StateNotifier<AsyncValue<List<CustomList>>> {
  CustomListsNotifier() : super(const AsyncValue.loading()) {
    _initialize();
  }

  final _uuid = const Uuid();

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localLists = await localStorageService.loadCustomLists();
      
      if (localLists.isEmpty) {
        // 初回起動時のみダミーデータを作成
        await _createInitialLists();
      } else {
        // order順にソート
        final sortedLists = List<CustomList>.from(localLists)
          ..sort((a, b) => a.order.compareTo(b.order));
        
        state = AsyncValue.data(sortedLists);
      }
    } catch (e) {
      print('⚠️ CustomList初期化エラー: $e');
      state = AsyncValue.data([]);
    }
  }

  /// 初回起動時のダミーデータを作成
  Future<void> _createInitialLists() async {
    final now = DateTime.now();
    
    final initialLists = [
      CustomList(
        id: _uuid.v4(),
        name: 'BRAIN DUMP',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CustomList(
        id: _uuid.v4(),
        name: 'GROCERY LIST',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CustomList(
        id: _uuid.v4(),
        name: 'TO BUY',
        order: 2,
        createdAt: now,
        updatedAt: now,
      ),
      CustomList(
        id: _uuid.v4(),
        name: 'NOSTR',
        order: 3,
        createdAt: now,
        updatedAt: now,
      ),
      CustomList(
        id: _uuid.v4(),
        name: 'WORK',
        order: 4,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    
    // ローカルストレージに保存
    await localStorageService.saveCustomLists(initialLists);
    
    // 状態に反映
    state = AsyncValue.data(initialLists);
  }

  /// 新しいリストを追加
  Future<void> addList(String name) async {
    if (name.trim().isEmpty) return;

    await state.whenData((lists) async {
      final now = DateTime.now();
      final newList = CustomList(
        id: _uuid.v4(),
        name: name.trim().toUpperCase(),
        order: _getNextOrder(lists),
        createdAt: now,
        updatedAt: now,
      );

      final updatedLists = [...lists, newList];
      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// リストを更新
  Future<void> updateList(CustomList list) async {
    await state.whenData((lists) async {
      final index = lists.indexWhere((l) => l.id == list.id);
      if (index == -1) return;

      final updatedList = list.copyWith(updatedAt: DateTime.now());
      final updatedLists = [...lists];
      updatedLists[index] = updatedList;

      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// リストを削除
  Future<void> deleteList(String id) async {
    await state.whenData((lists) async {
      final updatedLists = lists.where((l) => l.id != id).toList();
      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// リストを並び替え
  Future<void> reorderLists(int oldIndex, int newIndex) async {
    await state.whenData((lists) async {
      final updatedLists = List<CustomList>.from(lists);

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = updatedLists.removeAt(oldIndex);
      updatedLists.insert(newIndex, item);

      // orderを再計算
      for (var i = 0; i < updatedLists.length; i++) {
        updatedLists[i] = updatedLists[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        );
      }

      state = AsyncValue.data(updatedLists);

      // ローカルストレージに保存
      await localStorageService.saveCustomLists(updatedLists);
    }).value;
  }

  /// 次のorder値を取得
  int _getNextOrder(List<CustomList> lists) {
    if (lists.isEmpty) return 0;
    return lists.map((l) => l.order).reduce((a, b) => a > b ? a : b) + 1;
  }
}

