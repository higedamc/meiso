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
  /// UUID (Nostrイベントの'd' tagとしても使用)
  String get id => throw _privateConstructorUsedError;

  /// タスクのタイトル（Value Object）
  TodoTitle get title => throw _privateConstructorUsedError;

  /// 完了状態
  bool get completed => throw _privateConstructorUsedError;

  /// 日付（Value Object、null = Someday）
  TodoDate? get date => throw _privateConstructorUsedError;

  /// 同じ日付内での並び順
  int get order => throw _privateConstructorUsedError;

  /// 作成日時
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// 更新日時
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Nostrイベントの event ID (同期後に設定)
  String? get eventId => throw _privateConstructorUsedError;

  /// URLリンクプレビュー（テキストにURLが含まれる場合）
  LinkPreview? get linkPreview => throw _privateConstructorUsedError;

  /// リカーリングタスクの繰り返しパターン
  RecurrencePattern? get recurrence => throw _privateConstructorUsedError;

  /// 親リカーリングタスクのID（このタスクが自動生成されたインスタンスの場合）
  String? get parentRecurringId => throw _privateConstructorUsedError;

  /// カスタムリストID（SOMEDAYページのリストに属する場合）
  String? get customListId => throw _privateConstructorUsedError;

  /// Nostrへの同期が必要かどうか（楽観的UI更新用）
  bool get needsSync => throw _privateConstructorUsedError;

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
    LinkPreview? linkPreview,
    RecurrencePattern? recurrence,
    String? parentRecurringId,
    String? customListId,
    bool needsSync,
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
    Object? linkPreview = freezed,
    Object? recurrence = freezed,
    Object? parentRecurringId = freezed,
    Object? customListId = freezed,
    Object? needsSync = null,
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
    TodoTitle title,
    bool completed,
    TodoDate? date,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    String? eventId,
    LinkPreview? linkPreview,
    RecurrencePattern? recurrence,
    String? parentRecurringId,
    String? customListId,
    bool needsSync,
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
    Object? linkPreview = freezed,
    Object? recurrence = freezed,
    Object? parentRecurringId = freezed,
    Object? customListId = freezed,
    Object? needsSync = null,
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
    this.linkPreview,
    this.recurrence,
    this.parentRecurringId,
    this.customListId,
    required this.needsSync,
  }) : super._();

  /// UUID (Nostrイベントの'd' tagとしても使用)
  @override
  final String id;

  /// タスクのタイトル（Value Object）
  @override
  final TodoTitle title;

  /// 完了状態
  @override
  final bool completed;

  /// 日付（Value Object、null = Someday）
  @override
  final TodoDate? date;

  /// 同じ日付内での並び順
  @override
  final int order;

  /// 作成日時
  @override
  final DateTime createdAt;

  /// 更新日時
  @override
  final DateTime updatedAt;

  /// Nostrイベントの event ID (同期後に設定)
  @override
  final String? eventId;

  /// URLリンクプレビュー（テキストにURLが含まれる場合）
  @override
  final LinkPreview? linkPreview;

  /// リカーリングタスクの繰り返しパターン
  @override
  final RecurrencePattern? recurrence;

  /// 親リカーリングタスクのID（このタスクが自動生成されたインスタンスの場合）
  @override
  final String? parentRecurringId;

  /// カスタムリストID（SOMEDAYページのリストに属する場合）
  @override
  final String? customListId;

  /// Nostrへの同期が必要かどうか（楽観的UI更新用）
  @override
  final bool needsSync;

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, completed: $completed, date: $date, order: $order, createdAt: $createdAt, updatedAt: $updatedAt, eventId: $eventId, linkPreview: $linkPreview, recurrence: $recurrence, parentRecurringId: $parentRecurringId, customListId: $customListId, needsSync: $needsSync)';
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
            (identical(other.linkPreview, linkPreview) ||
                other.linkPreview == linkPreview) &&
            (identical(other.recurrence, recurrence) ||
                other.recurrence == recurrence) &&
            (identical(other.parentRecurringId, parentRecurringId) ||
                other.parentRecurringId == parentRecurringId) &&
            (identical(other.customListId, customListId) ||
                other.customListId == customListId) &&
            (identical(other.needsSync, needsSync) ||
                other.needsSync == needsSync));
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
    linkPreview,
    recurrence,
    parentRecurringId,
    customListId,
    needsSync,
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
    final LinkPreview? linkPreview,
    final RecurrencePattern? recurrence,
    final String? parentRecurringId,
    final String? customListId,
    required final bool needsSync,
  }) = _$TodoImpl;
  const _Todo._() : super._();

  /// UUID (Nostrイベントの'd' tagとしても使用)
  @override
  String get id;

  /// タスクのタイトル（Value Object）
  @override
  TodoTitle get title;

  /// 完了状態
  @override
  bool get completed;

  /// 日付（Value Object、null = Someday）
  @override
  TodoDate? get date;

  /// 同じ日付内での並び順
  @override
  int get order;

  /// 作成日時
  @override
  DateTime get createdAt;

  /// 更新日時
  @override
  DateTime get updatedAt;

  /// Nostrイベントの event ID (同期後に設定)
  @override
  String? get eventId;

  /// URLリンクプレビュー（テキストにURLが含まれる場合）
  @override
  LinkPreview? get linkPreview;

  /// リカーリングタスクの繰り返しパターン
  @override
  RecurrencePattern? get recurrence;

  /// 親リカーリングタスクのID（このタスクが自動生成されたインスタンスの場合）
  @override
  String? get parentRecurringId;

  /// カスタムリストID（SOMEDAYページのリストに属する場合）
  @override
  String? get customListId;

  /// Nostrへの同期が必要かどうか（楽観的UI更新用）
  @override
  bool get needsSync;

  /// Create a copy of Todo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TodoImplCopyWith<_$TodoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
