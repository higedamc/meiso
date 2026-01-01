import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_package.freezed.dart';

/// Key Packageのドメインエンティティ
/// 
/// MLS (Messaging Layer Security) で使用される公開鍵情報。
/// 他のユーザーがグループに招待する際に必要となる。
@freezed
class KeyPackage with _$KeyPackage {
  const factory KeyPackage({
    /// Key Package本体（Base64エンコード）
    required String keyPackage,
    
    /// 所有者の公開鍵（hex形式）
    required String ownerPubkey,
    
    /// 公開日時
    required DateTime publishedAt,
    
    /// NostrイベントID（任意）
    /// 
    /// Kind 10443イベントとして公開された場合のイベントID
    String? eventId,
    
    /// MLSプロトコルバージョン（任意）
    String? mlsProtocolVersion,
    
    /// Ciphersuite（任意）
    String? ciphersuite,
  }) = _KeyPackage;
  
  const KeyPackage._();
  
  /// Key Packageが期限切れか判定
  /// 
  /// MLS Protocol推奨: 最長7日間
  bool isExpired() {
    final elapsed = DateTime.now().difference(publishedAt);
    return elapsed.inDays >= 7;
  }
  
  /// 次回更新推奨日時を取得
  /// 
  /// 公開から3日後（推奨更新閾値）
  DateTime get recommendedRefreshTime {
    return publishedAt.add(const Duration(days: 3));
  }
  
  /// 更新が推奨される状態か判定
  bool shouldRefresh() {
    return DateTime.now().isAfter(recommendedRefreshTime);
  }
}

