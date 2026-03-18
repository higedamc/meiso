import 'dart:convert';

enum Gw17MessageType {
  invitation('group_invitation'),
  todoUpdate('todo_update'),
  todoSnapshot('todo_snapshot');

  const Gw17MessageType(this.value);
  final String value;

  static Gw17MessageType? fromValue(String? value) {
    for (final type in Gw17MessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

class Gw17GroupMessage {
  const Gw17GroupMessage({
    required this.type,
    required this.groupId,
    required this.groupName,
    required this.protocolVersion,
    required this.senderPubkey,
    required this.createdAtSec,
    this.schemaVersion = currentSchemaVersion,
    this.eventId,
    this.action,
    this.todo,
    this.todos,
  });

  static const int currentSchemaVersion = 1;

  final Gw17MessageType type;
  final String groupId;
  final String groupName;
  final String protocolVersion;
  final String senderPubkey;
  final int createdAtSec;
  final int schemaVersion;

  /// outer event ID (gift-wrap envelope) — set by the receiver, not serialised
  final String? eventId;

  final String? action;
  final Map<String, dynamic>? todo;
  final List<Map<String, dynamic>>? todos;

  Map<String, dynamic> toJson() {
    return {
      'v': schemaVersion,
      'type': type.value,
      'group_id': groupId,
      'group_name': groupName,
      'protocol': protocolVersion,
      'sender_pubkey': senderPubkey,
      'created_at': createdAtSec,
      if (action != null) 'action': action,
      if (todo != null) 'todo': todo,
      if (todos != null) 'todos': todos,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  Gw17GroupMessage copyWith({String? eventId}) {
    return Gw17GroupMessage(
      type: type,
      groupId: groupId,
      groupName: groupName,
      protocolVersion: protocolVersion,
      senderPubkey: senderPubkey,
      createdAtSec: createdAtSec,
      schemaVersion: schemaVersion,
      eventId: eventId ?? this.eventId,
      action: action,
      todo: todo,
      todos: todos,
    );
  }

  /// Strict deserialization with required-field validation.
  /// Returns null if the payload is malformed or missing required fields.
  static Gw17GroupMessage? fromJson(Map<String, dynamic> json) {
    final type = Gw17MessageType.fromValue(json['type'] as String?);
    if (type == null) return null;

    final groupId = json['group_id'] as String?;
    final groupName = json['group_name'] as String?;
    final protocol = json['protocol'] as String?;
    final senderPubkey = json['sender_pubkey'] as String?;
    final createdAt = json['created_at'] as int?;

    if (groupId == null ||
        groupId.isEmpty ||
        groupName == null ||
        groupName.isEmpty ||
        protocol == null ||
        protocol.isEmpty ||
        senderPubkey == null ||
        senderPubkey.isEmpty ||
        createdAt == null ||
        createdAt <= 0) {
      return null;
    }

    final schemaVersion = (json['v'] as int?) ?? 1;

    final action = json['action'] as String?;

    // type-specific required-field checks
    if (type == Gw17MessageType.todoUpdate) {
      if (action == null || action.isEmpty) return null;
      final rawTodo = json['todo'];
      if (rawTodo == null || rawTodo is! Map) return null;
      if ((rawTodo['id'] as String?)?.isEmpty ?? true) return null;
    }

    if (type == Gw17MessageType.todoSnapshot) {
      final rawTodos = json['todos'];
      if (rawTodos == null || rawTodos is! List || rawTodos.isEmpty) {
        return null;
      }
    }

    List<Map<String, dynamic>>? todos;
    final rawTodos = json['todos'];
    if (rawTodos is List) {
      todos = rawTodos
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    }

    Map<String, dynamic>? todo;
    final rawTodo = json['todo'];
    if (rawTodo is Map) {
      todo = rawTodo.map((key, value) => MapEntry(key.toString(), value));
    }

    return Gw17GroupMessage(
      type: type,
      groupId: groupId,
      groupName: groupName,
      protocolVersion: protocol,
      senderPubkey: senderPubkey,
      createdAtSec: createdAt,
      schemaVersion: schemaVersion,
      action: action,
      todo: todo,
      todos: todos,
    );
  }

  static Gw17GroupMessage? fromJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
