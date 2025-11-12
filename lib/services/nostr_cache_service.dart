import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../bridge_generated.dart/api.dart' as rust_api;
import '../services/logger_service.dart';

/// Nostrイベントのキャッシュを管理するサービス
class NostrCacheService {
  static const String _boxName = 'nostr_event_cache';
  static const int _defaultTTLSeconds = 300; // 5分
  
  late Box<String> _cacheBox;
  
  /// 初期化
  Future<void> init() async {
    _cacheBox = await Hive.openBox<String>(_boxName);
    AppLogger.debug('🗄️ Nostr cache service initialized');
  }
  
  /// キャッシュにイベントを保存
  Future<void> cacheEvent({
    required String eventJson,
    int ttlSeconds = _defaultTTLSeconds,
  }) async {
    try {
      // Rust側でキャッシュ情報を作成
      final cacheInfo = await rust_api.createCacheInfo(
        eventJson: eventJson,
        ttlSeconds: BigInt.from(ttlSeconds),
      );
      
      // キャッシュ情報をJSON化して保存
      final cacheInfoJson = jsonEncode({
        'event_id': cacheInfo.eventId,
        'kind': cacheInfo.kind,
        'created_at': cacheInfo.createdAt,
        'event_json': cacheInfo.eventJson,
        'cached_at': cacheInfo.cachedAt,
        'ttl_seconds': cacheInfo.ttlSeconds,
        'd_tag': cacheInfo.dTag,
      });
      
      // イベントIDをキーにして保存
      await _cacheBox.put(cacheInfo.eventId, cacheInfoJson);
      
      // d-tagがある場合は、(kind, d-tag)でもインデックス化
      if (cacheInfo.dTag != null) {
        final indexKey = '${cacheInfo.kind}:${cacheInfo.dTag}';
        await _cacheBox.put(indexKey, cacheInfoJson);
      }
      
      AppLogger.debug(' Cached event: ${cacheInfo.eventId}');
    } catch (e) {
      AppLogger.warning(' Failed to cache event: $e');
    }
  }
  
  /// イベントIDからキャッシュを取得
  Future<String?> getCachedEvent(String eventId) async {
    try {
      final cacheInfoJson = _cacheBox.get(eventId);
      if (cacheInfoJson == null) {
        return null;
      }
      
      // キャッシュ情報をパース
      final cacheData = jsonDecode(cacheInfoJson) as Map<String, dynamic>;
      final cacheInfo = rust_api.CachedEventInfo(
        eventId: cacheData['event_id'] as String,
        kind: BigInt.from(cacheData['kind'] as int),
        createdAt: cacheData['created_at'] as int,
        eventJson: cacheData['event_json'] as String,
        cachedAt: cacheData['cached_at'] as int,
        ttlSeconds: BigInt.from(cacheData['ttl_seconds'] as int),
        dTag: cacheData['d_tag'] as String?,
      );
      
      // キャッシュの有効性をチェック
      final isValid = await rust_api.isCacheValid(cacheInfo: cacheInfo);
      if (!isValid) {
        // 期限切れなので削除
        await _cacheBox.delete(eventId);
        AppLogger.debug(' Expired cache removed: $eventId');
        return null;
      }
      
      AppLogger.info(' Cache hit: $eventId');
      return cacheInfo.eventJson;
    } catch (e) {
      AppLogger.warning(' Failed to get cached event: $e');
      return null;
    }
  }
  
  /// (kind, d-tag)からキャッシュを取得（Replaceable event用）
  Future<String?> getCachedReplaceableEvent({
    required int kind,
    required String dTag,
  }) async {
    try {
      final indexKey = '$kind:$dTag';
      return await getCachedEvent(indexKey);
    } catch (e) {
      AppLogger.warning(' Failed to get cached replaceable event: $e');
      return null;
    }
  }
  
  /// キャッシュをクリア
  Future<void> clearCache() async {
    await _cacheBox.clear();
    AppLogger.debug(' Cache cleared');
  }
  
  /// 期限切れのキャッシュを削除
  Future<void> cleanExpiredCache() async {
    try {
      final keysToDelete = <String>[];
      
      for (final key in _cacheBox.keys) {
        final cacheInfoJson = _cacheBox.get(key);
        if (cacheInfoJson == null) continue;
        
        try {
          final cacheData = jsonDecode(cacheInfoJson) as Map<String, dynamic>;
          final cacheInfo = rust_api.CachedEventInfo(
            eventId: cacheData['event_id'] as String,
            kind: BigInt.from(cacheData['kind'] as int),
            createdAt: cacheData['created_at'] as int,
            eventJson: cacheData['event_json'] as String,
            cachedAt: cacheData['cached_at'] as int,
            ttlSeconds: BigInt.from(cacheData['ttl_seconds'] as int),
            dTag: cacheData['d_tag'] as String?,
          );
          
          final isValid = await rust_api.isCacheValid(cacheInfo: cacheInfo);
          if (!isValid) {
            keysToDelete.add(key as String);
          }
        } catch (e) {
          // パースエラーの場合も削除
          keysToDelete.add(key as String);
        }
      }
      
      for (final key in keysToDelete) {
        await _cacheBox.delete(key);
      }
      
      if (keysToDelete.isNotEmpty) {
        AppLogger.debug(' Cleaned ${keysToDelete.length} expired cache entries');
      }
    } catch (e) {
      AppLogger.warning(' Failed to clean expired cache: $e');
    }
  }
  
  /// キャッシュサイズを取得
  int get cacheSize => _cacheBox.length;
  
  /// すべてのキャッシュキーを取得
  Iterable<String> get allKeys => _cacheBox.keys.cast<String>();
}

