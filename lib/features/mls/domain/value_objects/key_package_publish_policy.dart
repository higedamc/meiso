/// Key Package公開ポリシー
/// 
/// MLS Protocol (RFC 9420) 推奨に従い、Key Packageの有効期限と
/// 公開タイミングを管理する。
/// 
/// 参考:
/// - TLS ticket_lifetime: 7日間
/// - Forward Secrecy: 使用後すぐに鍵を削除すべき
/// - 推奨更新頻度: 各メッセージ/状態変更ごと（理想）
enum KeyPackagePublishTrigger {
  /// アプリ起動時
  appStart,
  
  /// 招待受諾時
  invitationAccept,
  
  /// グループメッセージ送信前
  beforeGroupMessage,
  
  /// アカウント作成時
  accountCreation,
  
  /// 手動公開（Settings画面）
  manual,
}

/// Key Package公開ポリシー
/// 
/// MLS Protocol準拠のKey Package管理ポリシーを提供する。
class KeyPackagePublishPolicy {
  const KeyPackagePublishPolicy();
  
  /// MLS Protocol推奨: 最長7日間
  /// 
  /// RFC 9420準拠。TLS ticket_lifetimeと同じ期間。
  /// Key Packageはこの期間を超えたら必ず更新する。
  static const Duration maxKeyPackageLifetime = Duration(days: 7);
  
  /// 推奨更新閾値: 3日間
  /// 
  /// グループメッセージ送信前のチェックに使用。
  /// maxKeyPackageLifetimeの半分に設定することで、
  /// Forward Secrecyを確保しつつ、頻繁すぎる公開を避ける。
  static const Duration recommendedRefreshThreshold = Duration(days: 3);
  
  /// 公開が必要か判定
  /// 
  /// [trigger]: 公開トリガー
  /// [lastPublished]: 最後に公開した日時
  /// [forceUpload]: 強制公開フラグ（期限・キャッシュを無視）
  /// 
  /// Returns: 公開が必要な場合は true
  bool shouldPublish({
    required KeyPackagePublishTrigger trigger,
    DateTime? lastPublished,
    bool forceUpload = false,
  }) {
    // forceUploadフラグが立っている場合は無条件に公開
    if (forceUpload) return true;
    
    // 初回は必ず公開
    if (lastPublished == null) return true;
    
    final elapsed = DateTime.now().difference(lastPublished);
    
    switch (trigger) {
      case KeyPackagePublishTrigger.appStart:
        // アプリ起動時: 7日経過していれば必ず公開
        return elapsed >= maxKeyPackageLifetime;
      
      case KeyPackagePublishTrigger.invitationAccept:
        // 招待受諾時: forceUpload=trueで呼ばれることを想定
        // fallbackとして3日間経過をチェック
        return elapsed >= recommendedRefreshThreshold;
      
      case KeyPackagePublishTrigger.beforeGroupMessage:
        // グループメッセージ送信前: 3日経過していれば公開
        // Forward Secrecyを確保しつつ、頻繁すぎる公開を避ける
        return elapsed >= recommendedRefreshThreshold;
      
      case KeyPackagePublishTrigger.accountCreation:
        // アカウント作成時: 常に公開
        return true;
      
      case KeyPackagePublishTrigger.manual:
        // 手動公開: forceUpload=trueで呼ばれることを想定
        return true;
    }
  }
  
  /// 次回更新予定日時を取得
  /// 
  /// [lastPublished]: 最後に公開した日時
  /// 
  /// Returns: 次回更新が必要になる日時
  DateTime? getNextUpdateTime(DateTime? lastPublished) {
    if (lastPublished == null) return null;
    return lastPublished.add(recommendedRefreshThreshold);
  }
  
  /// Key Packageが期限切れかチェック
  /// 
  /// [lastPublished]: 最後に公開した日時
  /// 
  /// Returns: 7日間を超えている場合は true
  bool isExpired(DateTime? lastPublished) {
    if (lastPublished == null) return true;
    final elapsed = DateTime.now().difference(lastPublished);
    return elapsed >= maxKeyPackageLifetime;
  }
}

