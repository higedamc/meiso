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

/// @nodoc
mixin _$Todo {
  String get id => throw _privateConstructorUsedError;
  TodoTitle get title => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  TodoDate? get date => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String? get eventId => throw _privateConstructorUsedError;
  String? get linkPreviewJson => throw _privateConstructorUsedError;
  String? get recurrenceJson => throw _privateConstructorUsedError;
  String? get parentRecurringId => throw _privateConstructorUsedError;
  String? get customListId => throw _privateConstructorUsedError;
  bool get needsSync => throw _privateConstructorUsedError;

  /// 親タスクID（サブタスクの場合）
  String? get parentTaskId => throw _privateConstructorUsedError;

  /// ネスト深度（0 = ルート）
  int get depth => throw _privateConstructorUsedError;

  /// タスクリンク JSON（シリアライズ用）
  String? get taskLinksJson => throw _privateConstructorUsedError;

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
    TodoTitle title,
    bool completed,
    TodoDate? date,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    String? eventId,
    String? linkPreviewJson,
    String? recurrenceJson,
    String? parentRecurringId,
    String? customListId,
    bool needsSync,
    String? parentTaskId,
    int depth,
    String? taskLinksJson,
  });
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
    Object? linkPreviewJson = freezed,
    Object? recurrenceJson = freezed,
    Object? parentRecurringId = freezed,
    Object? customListId = freezed,
    Object? needsSync = null,
    Object? parentTaskId = freezed,
    Object? depth = null,
    Object? taskLinksJson = freezed,
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
                      as TodoTitle,
            completed: null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                      as bool,
            date: freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as TodoDate?,
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
            linkPreviewJson: freezed == linkPreviewJson
                ? _value.linkPreviewJson
                : linkPreviewJson // ignore: cast_nullable_to_non_nullable
                      as String?,
            recurrenceJson: freezed == recurrenceJson
                ? _value.recurrenceJson
                : recurrenceJson // ignore: cast_nullable_to_non_nullable
                      as String?,
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
            taskLinksJson: freezed == taskLinksJson
                ? _value.taskLinksJson
                : taskLinksJson // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
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
    TodoTitle title,
    bool completed,
    TodoDate? date,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    String? eventId,
    String? linkPreviewJson,
    String? recurrenceJson,
    String? parentRecurringId,
    String? customListId,
    bool needsSync,
    String? parentTaskId,
    int depth,
    String? taskLinksJson,
  });
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
    Object? linkPreviewJson = freezed,
    Object? recurrenceJson = freezed,
    Object? parentRecurringId = freezed,
    Object? customListId = freezed,
    Object? needsSync = null,
    Object? parentTaskId = freezed,
    Object? depth = null,
    Object? taskLinksJson = freezed,
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
                  as TodoTitle,
        completed: null == completed
            ? _value.completed
            : completed // ignore: cast_nullable_to_non_nullable
                  as bool,
        date: freezed == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as TodoDate?,
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
        linkPreviewJson: freezed == linkPreviewJson
            ? _value.linkPreviewJson
            : linkPreviewJson // ignore: cast_nullable_to_non_nullable
                  as String?,
        recurrenceJson: freezed == recurrenceJson
            ? _value.recurrenceJson
            : recurrenceJson // ignore: cast_nullable_to_non_nullable
                  as String?,
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
        taskLinksJson: freezed == taskLinksJson
            ? _value.taskLinksJson
            : taskLinksJson // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$TodoImpl extends _Todo {
  const _$TodoImpl({
    required this.id,
    required this.title,
    required this.completed,
    this.date,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.eventId,
    this.linkPreviewJson,
    this.recurrenceJson,
    this.parentRecurringId,
    this.customListId,
    required this.needsSync,
    this.parentTaskId,
    this.depth = 0,
    this.taskLinksJson,
  }) : super._();

  @override
  final String id;
  @override
  final TodoTitle title;
  @override
  final bool completed;
  @override
  final TodoDate? date;
  @override
  final int order;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String? eventId;
  @override
  final String? linkPreviewJson;
  @override
  final String? recurrenceJson;
  @override
  final String? parentRecurringId;
  @override
  final String? customListId;
  @override
  final bool needsSync;

  /// 親タスクID（サブタスクの場合）
  @override
  final String? parentTaskId;

  /// ネスト深度（0 = ルート）
  @override
  @JsonKey()
  final int depth;

  /// タスクリンク JSON（シリアライズ用）
  @override
  final String? taskLinksJson;

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, completed: $completed, date: $date, order: $order, createdAt: $createdAt, updatedAt: $updatedAt, eventId: $eventId, linkPreviewJson: $linkPreviewJson, recurrenceJson: $recurrenceJson, parentRecurringId: $parentRecurringId, customListId: $customListId, needsSync: $needsSync, parentTaskId: $parentTaskId, depth: $depth, taskLinksJson: $taskLinksJson)';
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
            (identical(other.linkPreviewJson, linkPreviewJson) ||
                other.linkPreviewJson == linkPreviewJson) &&
            (identical(other.recurrenceJson, recurrenceJson) ||
                other.recurrenceJson == recurrenceJson) &&
            (identical(other.parentRecurringId, parentRecurringId) ||
                other.parentRecurringId == parentRecurringId) &&
            (identical(other.customListId, customListId) ||
                other.customListId == customListId) &&
            (identical(other.needsSync, needsSync) ||
                other.needsSync == needsSync) &&
            (identical(other.parentTaskId, parentTaskId) ||
                other.parentTaskId == parentTaskId) &&
            (identical(other.depth, depth) || other.depth == depth) &&
            (identical(other.taskLinksJson, taskLinksJson) ||
                other.taskLinksJson == taskLinksJson));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    completed,
    date,
    order,
    createdAt,
    updatedAt,
    eventId,
    linkPreviewJson,
    recurrenceJson,
    parentRecurringId,
    customListId,
    needsSync,
    parentTaskId,
    depth,
    taskLinksJson,
  );

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TodoImplCopyWith<_$TodoImpl> get copyWith =>
      __$$TodoImplCopyWithImpl<_$TodoImpl>(this, _$identity);
}

abstract class _Todo extends Todo {
  const factory _Todo({
    required final String id,
    required final TodoTitle title,
    required final bool completed,
    final TodoDate? date,
    required final int order,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final String? eventId,
    final String? linkPreviewJson,
    final String? recurrenceJson,
    final String? parentRecurringId,
    final String? customListId,
    required final bool needsSync,
    final String? parentTaskId,
    final int depth,
    final String? taskLinksJson,
  }) = _$TodoImpl;
  const _Todo._() : super._();

  @override
  String get id;
  @override
  TodoTitle get title;
  @override
  bool get completed;
  @override
  TodoDate? get date;
  @override
  int get order;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  String? get eventId;
  @override
  String? get linkPreviewJson;
  @override
  String? get recurrenceJson;
  @override
  String? get parentRecurringId;
  @override
  String? get customListId;
  @override
  bool get needsSync;

  /// 親タスクID（サブタスクの場合）
  @override
  String? get parentTaskId;

  /// ネスト深度（0 = ルート）
  @override
  int get depth;

  /// タスクリンク JSON（シリアライズ用）
  @override
  String? get taskLinksJson;

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TodoImplCopyWith<_$TodoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
