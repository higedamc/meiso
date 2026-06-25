/// 共有リスト用グループ鍵 G のローカル保持データ
class SharedGroupCredentials {
  const SharedGroupCredentials({
    required this.groupId,
    required this.groupNsecHex,
    required this.groupNpubHex,
    this.keyEpoch = 1,
  });

  final String groupId;
  final String groupNsecHex;
  final String groupNpubHex;
  final int keyEpoch;

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'group_nsec': groupNsecHex,
        'group_npub': groupNpubHex,
        'key_epoch': keyEpoch,
      };

  factory SharedGroupCredentials.fromJson(Map<String, dynamic> json) {
    return SharedGroupCredentials(
      groupId: json['group_id'] as String,
      groupNsecHex: json['group_nsec'] as String,
      groupNpubHex: json['group_npub'] as String,
      keyEpoch: (json['key_epoch'] as num?)?.toInt() ?? 1,
    );
  }
}
