/// shared-v1 招待（NIP-44 暗号化 content を保持）
class SharedInvitation {
  const SharedInvitation({
    required this.groupId,
    required this.groupName,
    required this.encryptedContent,
    required this.inviterPubkey,
    required this.createdAt,
    this.inviterName,
    this.eventId,
  });

  final String groupId;
  final String groupName;
  final String encryptedContent;
  final String inviterPubkey;
  final String? inviterName;
  final DateTime createdAt;
  final String? eventId;
}
