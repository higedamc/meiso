import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_invitation.freezed.dart';

/// グループ招待のドメインエンティティ
/// 
/// MLSグループへの招待情報を表現する。
/// 受信した招待はローカルストレージに保存され、
/// ユーザーが受諾するまでペンディング状態となる。
@freezed
class GroupInvitation with _$GroupInvitation {
  const factory GroupInvitation({
    /// グループID
    required String groupId,
    
    /// グループ名
    required String groupName,
    
    /// Welcome Message（Base64エンコード）
    /// 
    /// 招待者がMLS APIで生成したWelcome Message。
    /// 受諾時にこのメッセージを使用してグループに参加する。
    required String welcomeMessage,
    
    /// 招待者の公開鍵（hex形式）
    required String inviterPubkey,
    
    /// 招待者の名前（任意）
    String? inviterName,
    
    /// 招待を受信した日時
    required DateTime receivedAt,
    
    /// ペンディング状態
    /// 
    /// true: ユーザーがまだ受諾していない
    /// false: 受諾済み
    required bool isPending,
    
    /// 受諾日時（任意）
    DateTime? acceptedAt,
  }) = _GroupInvitation;
  
  const GroupInvitation._();
  
  /// 招待が期限切れか判定
  /// 
  /// Welcome Messageは7日間有効（MLS Protocol推奨）
  bool isExpired() {
    final elapsed = DateTime.now().difference(receivedAt);
    return elapsed.inDays >= 7;
  }
  
  /// 招待者の表示名を取得
  String get inviterDisplayName {
    if (inviterName != null && inviterName!.isNotEmpty) {
      return inviterName!;
    }
    // npubの最初の16文字を表示
    return '${inviterPubkey.substring(0, 16)}...';
  }
}

