import 'package:hive/hive.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/value_objects/list_name.dart';

/// カスタムリストのローカルデータソース（Hive）
abstract class CustomListLocalDataSource {
  /// 全てのカスタムリストを取得
  Future<List<CustomList>> getAllCustomLists();
  
  /// カスタムリストを保存（複数）
  Future<void> saveCustomLists(List<CustomList> lists);
  
  /// カスタムリストを追加
  Future<void> addCustomList(CustomList customList);
  
  /// カスタムリストを更新
  Future<void> updateCustomList(CustomList customList);
  
  /// カスタムリストを削除
  Future<void> deleteCustomList(String id);
  
  /// 全てクリア
  Future<void> clearAll();
}

/// Hiveを使用したCustomListLocalDataSourceの実装
class CustomListLocalDataSourceHive implements CustomListLocalDataSource {
  CustomListLocalDataSourceHive({required this.boxName});
  
  final String boxName;
  Box<Map>? _box;
  
  /// Hiveボックスを取得（遅延初期化）
  Future<Box<Map>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<Map>(boxName);
    }
    return _box!;
  }
  
  @override
  Future<List<CustomList>> getAllCustomLists() async {
    final box = await _getBox();
    final lists = <CustomList>[];
    
    for (final value in box.values) {
      try {
        final jsonMap = _deepCastMap(value);
        lists.add(_fromJson(jsonMap));
      } catch (e) {
        // エラーが発生したアイテムはスキップ
        continue;
      }
    }
    
    // order順にソート
    lists.sort((a, b) => a.order.compareTo(b.order));
    
    return lists;
  }
  
  @override
  Future<void> saveCustomLists(List<CustomList> lists) async {
    final box = await _getBox();
    
    // 既存データをクリア
    await box.clear();
    
    // 新しいデータを保存
    for (final list in lists) {
      await box.put(list.id, _toJson(list));
    }
  }
  
  @override
  Future<void> addCustomList(CustomList customList) async {
    final box = await _getBox();
    await box.put(customList.id, _toJson(customList));
  }
  
  @override
  Future<void> updateCustomList(CustomList customList) async {
    final box = await _getBox();
    await box.put(customList.id, _toJson(customList));
  }
  
  @override
  Future<void> deleteCustomList(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }
  
  @override
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
  
  /// CustomList → JSON変換
  Map<String, dynamic> _toJson(CustomList list) {
    return {
      'id': list.id,
      'name': list.name.value,
      'order': list.order,
      'createdAt': list.createdAt.toIso8601String(),
      'updatedAt': list.updatedAt.toIso8601String(),
    };
  }
  
  /// JSON → CustomList変換
  CustomList _fromJson(Map<String, dynamic> json) {
    final nameResult = ListName.create(json['name'] as String);
    
      // バリデーションエラーの場合は元の値を使用
      final name = nameResult.fold(
        (failure) => ListName.create('UNNAMED').getOrElse(() => throw Exception('Should never happen')),
        (validName) => validName,
      );
    
    return CustomList(
      id: json['id'] as String,
      name: name,
      order: json['order'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
  
  /// Mapの深いキャストを行う（Hiveのデシリアライズ対応）
  Map<String, dynamic> _deepCastMap(dynamic value) {
    if (value is! Map) {
      throw Exception('Expected Map, got ${value.runtimeType}');
    }
    
    return Map<String, dynamic>.from(
      value.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _deepCastMap(value));
        } else if (value is List) {
          return MapEntry(key.toString(), _deepCastList(value));
        }
        return MapEntry(key.toString(), value);
      }),
    );
  }
  
  /// Listの深いキャストを行う（Hiveのデシリアライズ対応）
  List<dynamic> _deepCastList(List value) {
    return value.map((item) {
      if (item is Map) {
        return _deepCastMap(item);
      } else if (item is List) {
        return _deepCastList(item);
      }
      return item;
    }).toList();
  }
}

