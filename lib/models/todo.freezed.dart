// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Todo _$TodoFromJson(Map<String, dynamic> json) {
  return _Todo.fromJson(json);
}

/// @nodoc
mixin _$Todo {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  DateTime? get date => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String? get eventId => throw _privateConstructorUsedError;
  String? get localOpId => throw _privateConstructorUsedError;
  DateTime? get localRelaySyncedAt => throw _privateConstructorUsedError;
  DateTime? get globalRelaySyncedAt => throw _privateConstructorUsedError;
  bool get globalSyncPending => throw _privateConstructorUsedError;
  bool get globalSyncFailed => throw _privateConstructorUsedError;
  LinkPreview? get linkPreview => throw _privateConstructorUsedError;
  RecurrencePattern? get recurrence => throw _privateConstructorUsedError;
  String? get parentRecurringId => throw _privateConstructorUsedError;
  String? get customListId => throw _privateConstructorUsedError;
  bool get needsSync => throw _privateConstructorUsedError;

  /// 親タスクID（サブタスクの場合に設定）
  /// NIP-XXA 互換: ["a", "35001:<pubkey>:<parent-d>", "", "parent"]
  String? get parentTaskId => throw _privateConstructorUsedError;

  /// ネスト深度（0 = ルートタスク、表示用キャッシュ）
  int get depth => throw _privateConstructorUsedError;

  /// タスクリンク（blocks, blocked_by, related_to, duplicate_of）
  List<TaskLink> get taskLinks => throw _privateConstructorUsedError;

  /// 添付画像のURL（Blossom/NIP-96経由でアップロード済み）
  String? get imageUrl => throw _privateConstructorUsedError;

  /// 共有リスト(shared-v1)で、このタスクを最後に追加/編集した実 npub(hex)。
  /// 自分以外が編集したタスクを UI 上で区別するために使用する。
  String? get editorPubkey => throw _privateConstructorUsedError;

  /// Serializes this Todo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TodoCopyWith<Todo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TodoCopyWith<$Res> {
  factory $TodoCopyWith(Todo value, $Res Function(Todo) then) =
      _$TodoCopyWithImpl<$Res, Todo>;
  @useResult
  $Res call({
    String id,
    String title,
    bool completed,
    DateTime? date,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    String? eventId,
    String? localOpId,
    DateTime? localRelaySyncedAt,
    DateTime? globalRelaySyncedAt,
    bool globalSyncPending,
    bool globalSyncFailed,
    LinkPreview? linkPreview,
    RecurrencePattern? recurrence,
    String? parentRecurringId,
    String? customListId,
    bool needsSync,
    String? parentTaskId,
    int depth,
    List<TaskLink> taskLinks,
    String? imageUrl,
    String? editorPubkey,
  });

  $LinkPreviewCopyWith<$Res>? get linkPreview;
  $RecurrencePatternCopyWith<$Res>? get recurrence;
}

/// @nodoc
class _$TodoCopyWithImpl<$Res, $Val extends Todo>
    implements $TodoCopyWith<$Res> {
  _$TodoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? completed = null,
    Object? date = freezed,
    Object? order = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? eventId = freezed,
    Object? localOpId = freezed,
    Object? localRelaySyncedAt = freezed,
    Object? globalRelaySyncedAt = freezed,
    Object? globalSyncPending = null,
    Object? globalSyncFailed = null,
    Object? linkPreview = freezed,
    Object? recurrence = freezed,
    Object? parentRecurringId = freezed,
    Object? customListId = freezed,
    Object? needsSync = null,
    Object? parentTaskId = freezed,
    Object? depth = null,
    Object? taskLinks = null,
    Object? imageUrl = freezed,
    Object? editorPubkey = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            completed: null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                      as bool,
            date: freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            order: null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            eventId: freezed == eventId
                ? _value.eventId
                : eventId // ignore: cast_nullable_to_non_nullable
                      as String?,
            localOpId: freezed == localOpId
                ? _value.localOpId
                : localOpId // ignore: cast_nullable_to_non_nullable
                      as String?,
            localRelaySyncedAt: freezed == localRelaySyncedAt
                ? _value.localRelaySyncedAt
                : localRelaySyncedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            globalRelaySyncedAt: freezed == globalRelaySyncedAt
                ? _value.globalRelaySyncedAt
                : globalRelaySyncedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            globalSyncPending: null == globalSyncPending
                ? _value.globalSyncPending
                : globalSyncPending // ignore: cast_nullable_to_non_nullable
                      as bool,
            globalSyncFailed: null == globalSyncFailed
                ? _value.globalSyncFailed
                : globalSyncFailed // ignore: cast_nullable_to_non_nullable
                      as bool,
            linkPreview: freezed == linkPreview
                ? _value.linkPreview
                : linkPreview // ignore: cast_nullable_to_non_nullable
                      as LinkPreview?,
            recurrence: freezed == recurrence
                ? _value.recurrence
                : recurrence // ignore: cast_nullable_to_non_nullable
                      as RecurrencePattern?,
            parentRecurringId: freezed == parentRecurringId
                ? _value.parentRecurringId
                : parentRecurringId // ignore: cast_nullable_to_non_nullable
                      as String?,
            customListId: freezed == customListId
                ? _value.customListId
                : customListId // ignore: cast_nullable_to_non_nullable
                      as String?,
            needsSync: null == needsSync
                ? _value.needsSync
                : needsSync // ignore: cast_nullable_to_non_nullable
                      as bool,
            parentTaskId: freezed == parentTaskId
                ? _value.parentTaskId
                : parentTaskId // ignore: cast_nullable_to_non_nullable
                      as String?,
            depth: null == depth
                ? _value.depth
                : depth // ignore: cast_nullable_to_non_nullable
                      as int,
            taskLinks: null == taskLinks
                ? _value.taskLinks
                : taskLinks // ignore: cast_nullable_to_non_nullable
                      as List<TaskLink>,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            editorPubkey: freezed == editorPubkey
                ? _value.editorPubkey
                : editorPubkey // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LinkPreviewCopyWith<$Res>? get linkPreview {
    if (_value.linkPreview == null) {
      return null;
    }

    return $LinkPreviewCopyWith<$Res>(_value.linkPreview!, (value) {
      return _then(_value.copyWith(linkPreview: value) as $Val);
    });
  }

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecurrencePatternCopyWith<$Res>? get recurrence {
    if (_value.recurrence == null) {
      return null;
    }

    return $RecurrencePatternCopyWith<$Res>(_value.recurrence!, (value) {
      return _then(_value.copyWith(recurrence: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TodoImplCopyWith<$Res> implements $TodoCopyWith<$Res> {
  factory _$$TodoImplCopyWith(
    _$TodoImpl value,
    $Res Function(_$TodoImpl) then,
  ) = __$$TodoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    bool completed,
    DateTime? date,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    String? eventId,
    String? localOpId,
    DateTime? localRelaySyncedAt,
    DateTime? globalRelaySyncedAt,
    bool globalSyncPending,
    bool globalSyncFailed,
    LinkPreview? linkPreview,
    RecurrencePattern? recurrence,
    String? parentRecurringId,
    String? customListId,
    bool needsSync,
    String? parentTaskId,
    int depth,
    List<TaskLink> taskLinks,
    String? imageUrl,
    String? editorPubkey,
  });

  @override
  $LinkPreviewCopyWith<$Res>? get linkPreview;
  @override
  $RecurrencePatternCopyWith<$Res>? get recurrence;
}

/// @nodoc
class __$$TodoImplCopyWithImpl<$Res>
    extends _$TodoCopyWithImpl<$Res, _$TodoImpl>
    implements _$$TodoImplCopyWith<$Res> {
  __$$TodoImplCopyWithImpl(_$TodoImpl _value, $Res Function(_$TodoImpl) _then)
    : super(_value, _then);

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? completed = null,
    Object? date = freezed,
    Object? order = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? eventId = freezed,
    Object? localOpId = freezed,
    Object? localRelaySyncedAt = freezed,
    Object? globalRelaySyncedAt = freezed,
    Object? globalSyncPending = null,
    Object? globalSyncFailed = null,
    Object? linkPreview = freezed,
    Object? recurrence = freezed,
    Object? parentRecurringId = freezed,
    Object? customListId = freezed,
    Object? needsSync = null,
    Object? parentTaskId = freezed,
    Object? depth = null,
    Object? taskLinks = null,
    Object? imageUrl = freezed,
    Object? editorPubkey = freezed,
  }) {
    return _then(
      _$TodoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        completed: null == completed
            ? _value.completed
            : completed // ignore: cast_nullable_to_non_nullable
                  as bool,
        date: freezed == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        order: null == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        eventId: freezed == eventId
            ? _value.eventId
            : eventId // ignore: cast_nullable_to_non_nullable
                  as String?,
        localOpId: freezed == localOpId
            ? _value.localOpId
            : localOpId // ignore: cast_nullable_to_non_nullable
                  as String?,
        localRelaySyncedAt: freezed == localRelaySyncedAt
            ? _value.localRelaySyncedAt
            : localRelaySyncedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        globalRelaySyncedAt: freezed == globalRelaySyncedAt
            ? _value.globalRelaySyncedAt
            : globalRelaySyncedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        globalSyncPending: null == globalSyncPending
            ? _value.globalSyncPending
            : globalSyncPending // ignore: cast_nullable_to_non_nullable
                  as bool,
        globalSyncFailed: null == globalSyncFailed
            ? _value.globalSyncFailed
            : globalSyncFailed // ignore: cast_nullable_to_non_nullable
                  as bool,
        linkPreview: freezed == linkPreview
            ? _value.linkPreview
            : linkPreview // ignore: cast_nullable_to_non_nullable
                  as LinkPreview?,
        recurrence: freezed == recurrence
            ? _value.recurrence
            : recurrence // ignore: cast_nullable_to_non_nullable
                  as RecurrencePattern?,
        parentRecurringId: freezed == parentRecurringId
            ? _value.parentRecurringId
            : parentRecurringId // ignore: cast_nullable_to_non_nullable
                  as String?,
        customListId: freezed == customListId
            ? _value.customListId
            : customListId // ignore: cast_nullable_to_non_nullable
                  as String?,
        needsSync: null == needsSync
            ? _value.needsSync
            : needsSync // ignore: cast_nullable_to_non_nullable
                  as bool,
        parentTaskId: freezed == parentTaskId
            ? _value.parentTaskId
            : parentTaskId // ignore: cast_nullable_to_non_nullable
                  as String?,
        depth: null == depth
            ? _value.depth
            : depth // ignore: cast_nullable_to_non_nullable
                  as int,
        taskLinks: null == taskLinks
            ? _value.taskLinks
            : taskLinks // ignore: cast_nullable_to_non_nullable
                  as List<TaskLink>,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        editorPubkey: freezed == editorPubkey
            ? _value.editorPubkey
            : editorPubkey // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TodoImpl implements _Todo {
  const _$TodoImpl({
    required this.id,
    required this.title,
    this.completed = false,
    this.date,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
    this.eventId,
    this.localOpId,
    this.localRelaySyncedAt,
    this.globalRelaySyncedAt,
    this.globalSyncPending = false,
    this.globalSyncFailed = false,
    this.linkPreview,
    this.recurrence,
    this.parentRecurringId,
    this.customListId,
    this.needsSync = true,
    this.parentTaskId,
    this.depth = 0,
    this.taskLinks = const [],
    this.imageUrl,
    this.editorPubkey,
  });

  factory _$TodoImpl.fromJson(Map<String, dynamic> json) =>
      _$$TodoImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final bool completed;
  @override
  final DateTime? date;
  @override
  @JsonKey()
  final int order;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String? eventId;
  @override
  final String? localOpId;
  @override
  final DateTime? localRelaySyncedAt;
  @override
  final DateTime? globalRelaySyncedAt;
  @override
  @JsonKey()
  final bool globalSyncPending;
  @override
  @JsonKey()
  final bool globalSyncFailed;
  @override
  final LinkPreview? linkPreview;
  @override
  final RecurrencePattern? recurrence;
  @override
  final String? parentRecurringId;
  @override
  final String? customListId;
  @override
  @JsonKey()
  final bool needsSync;

  /// 親タスクID（サブタスクの場合に設定）
  /// NIP-XXA 互換: ["a", "35001:<pubkey>:<parent-d>", "", "parent"]
  @override
  final String? parentTaskId;

  /// ネスト深度（0 = ルートタスク、表示用キャッシュ）
  @override
  @JsonKey()
  final int depth;

  /// タスクリンク（blocks, blocked_by, related_to, duplicate_of）
  @override
  @JsonKey()
  final List<TaskLink> taskLinks;

  /// 添付画像のURL（Blossom/NIP-96経由でアップロード済み）
  @override
  final String? imageUrl;

  /// 共有リスト(shared-v1)で、このタスクを最後に追加/編集した実 npub(hex)。
  /// 自分以外が編集したタスクを UI 上で区別するために使用する。
  @override
  final String? editorPubkey;

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, completed: $completed, date: $date, order: $order, createdAt: $createdAt, updatedAt: $updatedAt, eventId: $eventId, localOpId: $localOpId, localRelaySyncedAt: $localRelaySyncedAt, globalRelaySyncedAt: $globalRelaySyncedAt, globalSyncPending: $globalSyncPending, globalSyncFailed: $globalSyncFailed, linkPreview: $linkPreview, recurrence: $recurrence, parentRecurringId: $parentRecurringId, customListId: $customListId, needsSync: $needsSync, parentTaskId: $parentTaskId, depth: $depth, taskLinks: $taskLinks, imageUrl: $imageUrl, editorPubkey: $editorPubkey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TodoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.localOpId, localOpId) ||
                other.localOpId == localOpId) &&
            (identical(other.localRelaySyncedAt, localRelaySyncedAt) ||
                other.localRelaySyncedAt == localRelaySyncedAt) &&
            (identical(other.globalRelaySyncedAt, globalRelaySyncedAt) ||
                other.globalRelaySyncedAt == globalRelaySyncedAt) &&
            (identical(other.globalSyncPending, globalSyncPending) ||
                other.globalSyncPending == globalSyncPending) &&
            (identical(other.globalSyncFailed, globalSyncFailed) ||
                other.globalSyncFailed == globalSyncFailed) &&
            (identical(other.linkPreview, linkPreview) ||
                other.linkPreview == linkPreview) &&
            (identical(other.recurrence, recurrence) ||
                other.recurrence == recurrence) &&
            (identical(other.parentRecurringId, parentRecurringId) ||
                other.parentRecurringId == parentRecurringId) &&
            (identical(other.customListId, customListId) ||
                other.customListId == customListId) &&
            (identical(other.needsSync, needsSync) ||
                other.needsSync == needsSync) &&
            (identical(other.parentTaskId, parentTaskId) ||
                other.parentTaskId == parentTaskId) &&
            (identical(other.depth, depth) || other.depth == depth) &&
            const DeepCollectionEquality().equals(other.taskLinks, taskLinks) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.editorPubkey, editorPubkey) ||
                other.editorPubkey == editorPubkey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    completed,
    date,
    order,
    createdAt,
    updatedAt,
    eventId,
    localOpId,
    localRelaySyncedAt,
    globalRelaySyncedAt,
    globalSyncPending,
    globalSyncFailed,
    linkPreview,
    recurrence,
    parentRecurringId,
    customListId,
    needsSync,
    parentTaskId,
    depth,
    const DeepCollectionEquality().hash(taskLinks),
    imageUrl,
    editorPubkey,
  ]);

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TodoImplCopyWith<_$TodoImpl> get copyWith =>
      __$$TodoImplCopyWithImpl<_$TodoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TodoImplToJson(this);
  }
}

abstract class _Todo implements Todo {
  const factory _Todo({
    required final String id,
    required final String title,
    final bool completed,
    final DateTime? date,
    final int order,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final String? eventId,
    final String? localOpId,
    final DateTime? localRelaySyncedAt,
    final DateTime? globalRelaySyncedAt,
    final bool globalSyncPending,
    final bool globalSyncFailed,
    final LinkPreview? linkPreview,
    final RecurrencePattern? recurrence,
    final String? parentRecurringId,
    final String? customListId,
    final bool needsSync,
    final String? parentTaskId,
    final int depth,
    final List<TaskLink> taskLinks,
    final String? imageUrl,
    final String? editorPubkey,
  }) = _$TodoImpl;

  factory _Todo.fromJson(Map<String, dynamic> json) = _$TodoImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  bool get completed;
  @override
  DateTime? get date;
  @override
  int get order;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  String? get eventId;
  @override
  String? get localOpId;
  @override
  DateTime? get localRelaySyncedAt;
  @override
  DateTime? get globalRelaySyncedAt;
  @override
  bool get globalSyncPending;
  @override
  bool get globalSyncFailed;
  @override
  LinkPreview? get linkPreview;
  @override
  RecurrencePattern? get recurrence;
  @override
  String? get parentRecurringId;
  @override
  String? get customListId;
  @override
  bool get needsSync;

  /// 親タスクID（サブタスクの場合に設定）
  /// NIP-XXA 互換: ["a", "35001:<pubkey>:<parent-d>", "", "parent"]
  @override
  String? get parentTaskId;

  /// ネスト深度（0 = ルートタスク、表示用キャッシュ）
  @override
  int get depth;

  /// タスクリンク（blocks, blocked_by, related_to, duplicate_of）
  @override
  List<TaskLink> get taskLinks;

  /// 添付画像のURL（Blossom/NIP-96経由でアップロード済み）
  @override
  String? get imageUrl;

  /// 共有リスト(shared-v1)で、このタスクを最後に追加/編集した実 npub(hex)。
  /// 自分以外が編集したタスクを UI 上で区別するために使用する。
  @override
  String? get editorPubkey;

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TodoImplCopyWith<_$TodoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
