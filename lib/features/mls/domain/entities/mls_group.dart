import 'package:freezed_annotation/freezed_annotation.dart';

part 'mls_group.freezed.dart';

/// MLSグループのドメインエンティティ
/// 
/// MLS (Messaging Layer Security) で暗号化されたグループの
/// ビジネス情報を表現する。
@freezed
class MlsGroup with _$MlsGroup {
  const factory MlsGroup({
    /// グループID（UUID v4）
    required String groupId,
    
    /// グループ名
    required String groupName,
    
    /// グループメンバーの公開鍵リスト（hex形式）
    required List<String> memberPubkeys,
    
    /// Welcome Message（Base64エンコード）
    /// 
    /// 招待時に生成され、新メンバーに送信される。
    /// 新メンバーはこのWelcome Messageを使用してグループに参加する。
    String? welcomeMessage,
    
    /// 作成日時
    required DateTime createdAt,
    
    /// 更新日時
    required DateTime updatedAt,
  }) = _MlsGroup;
  
  const MlsGroup._();
  
  /// メンバー数を取得
  int get memberCount => memberPubkeys.length;
  
  /// Welcome Messageが存在するか
  bool get hasWelcomeMessage => welcomeMessage != null;
}

