import 'package:hive/hive.dart';
import '../../domain/entities/app_settings.dart';

/// アプリ設定のローカルデータソース（Hive）
abstract class AppSettingsLocalDataSource {
  /// アプリ設定を取得
  Future<AppSettings?> getAppSettings();
  
  /// アプリ設定を保存
  Future<void> saveAppSettings(AppSettings settings);
  
  /// アプリ設定を削除
  Future<void> deleteAppSettings();
}

/// Hiveを使用したAppSettingsLocalDataSourceの実装
class AppSettingsLocalDataSourceHive implements AppSettingsLocalDataSource {
  AppSettingsLocalDataSourceHive({required this.boxName});
  
  final String boxName;
  static const String _appSettingsKey = 'app_settings';
  Box<Map>? _box;
  
  /// Hiveボックスを取得（遅延初期化）
  Future<Box<Map>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<Map>(boxName);
    }
    return _box!;
  }
  
  @override
  Future<AppSettings?> getAppSettings() async {
    final box = await _getBox();
    final settingsMap = box.get(_appSettingsKey);
    
    if (settingsMap == null) {
      return null;
    }
    
    try {
      final jsonMap = _deepCastMap(settingsMap);
      return _fromJson(jsonMap);
    } catch (e) {
      // エラーが発生した場合はnullを返す
      return null;
    }
  }
  
  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    final box = await _getBox();
    await box.put(_appSettingsKey, _toJson(settings));
  }
  
  @override
  Future<void> deleteAppSettings() async {
    final box = await _getBox();
    await box.delete(_appSettingsKey);
  }
  
  /// AppSettings → JSON変換
  Map<String, dynamic> _toJson(AppSettings settings) {
    return {
      'darkMode': settings.darkMode,
      'weekStartDay': settings.weekStartDay,
      'calendarView': settings.calendarView,
      'notificationsEnabled': settings.notificationsEnabled,
      'relays': settings.relays,
      'torEnabled': settings.torEnabled,
      'proxyUrl': settings.proxyUrl,
      'customListOrder': settings.customListOrder,
      'lastViewedCustomListId': settings.lastViewedCustomListId,
      'updatedAt': settings.updatedAt.toIso8601String(),
    };
  }
  
  /// JSON → AppSettings変換
  AppSettings _fromJson(Map<String, dynamic> json) {
    return AppSettings(
      darkMode: json['darkMode'] as bool? ?? false,
      weekStartDay: json['weekStartDay'] as int? ?? 1,
      calendarView: json['calendarView'] as String? ?? 'week',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      relays: (json['relays'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      torEnabled: json['torEnabled'] as bool? ?? false,
      proxyUrl: json['proxyUrl'] as String? ?? 'socks5://127.0.0.1:9050',
      customListOrder: (json['customListOrder'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      lastViewedCustomListId: json['lastViewedCustomListId'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
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

