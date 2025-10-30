// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_status_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SyncStatus {
  SyncState get state => throw _privateConstructorUsedError;

  /// 最終同期日時
  DateTime? get lastSyncTime => throw _privateConstructorUsedError;

  /// エラーメッセージ（エラー時のみ）
  String? get errorMessage => throw _privateConstructorUsedError;

  /// 同期中のメッセージ（「データ読み込み中...」「データ移行中...」など）
  String? get message => throw _privateConstructorUsedError;

  /// 同期待ちのアイテム数
  int get pendingItems => throw _privateConstructorUsedError;

  /// リトライ回数
  int get retryCount => throw _privateConstructorUsedError;

  /// Create a copy of SyncStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncStatusCopyWith<SyncStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncStatusCopyWith<$Res> {
  factory $SyncStatusCopyWith(
    SyncStatus value,
    $Res Function(SyncStatus) then,
  ) = _$SyncStatusCopyWithImpl<$Res, SyncStatus>;
  @useResult
  $Res call({
    SyncState state,
    DateTime? lastSyncTime,
    String? errorMessage,
    String? message,
    int pendingItems,
    int retryCount,
  });
}

/// @nodoc
class _$SyncStatusCopyWithImpl<$Res, $Val extends SyncStatus>
    implements $SyncStatusCopyWith<$Res> {
  _$SyncStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? lastSyncTime = freezed,
    Object? errorMessage = freezed,
    Object? message = freezed,
    Object? pendingItems = null,
    Object? retryCount = null,
  }) {
    return _then(
      _value.copyWith(
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as SyncState,
            lastSyncTime: freezed == lastSyncTime
                ? _value.lastSyncTime
                : lastSyncTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            message: freezed == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String?,
            pendingItems: null == pendingItems
                ? _value.pendingItems
                : pendingItems // ignore: cast_nullable_to_non_nullable
                      as int,
            retryCount: null == retryCount
                ? _value.retryCount
                : retryCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SyncStatusImplCopyWith<$Res>
    implements $SyncStatusCopyWith<$Res> {
  factory _$$SyncStatusImplCopyWith(
    _$SyncStatusImpl value,
    $Res Function(_$SyncStatusImpl) then,
  ) = __$$SyncStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SyncState state,
    DateTime? lastSyncTime,
    String? errorMessage,
    String? message,
    int pendingItems,
    int retryCount,
  });
}

/// @nodoc
class __$$SyncStatusImplCopyWithImpl<$Res>
    extends _$SyncStatusCopyWithImpl<$Res, _$SyncStatusImpl>
    implements _$$SyncStatusImplCopyWith<$Res> {
  __$$SyncStatusImplCopyWithImpl(
    _$SyncStatusImpl _value,
    $Res Function(_$SyncStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SyncStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? lastSyncTime = freezed,
    Object? errorMessage = freezed,
    Object? message = freezed,
    Object? pendingItems = null,
    Object? retryCount = null,
  }) {
    return _then(
      _$SyncStatusImpl(
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as SyncState,
        lastSyncTime: freezed == lastSyncTime
            ? _value.lastSyncTime
            : lastSyncTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        message: freezed == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String?,
        pendingItems: null == pendingItems
            ? _value.pendingItems
            : pendingItems // ignore: cast_nullable_to_non_nullable
                  as int,
        retryCount: null == retryCount
            ? _value.retryCount
            : retryCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$SyncStatusImpl implements _SyncStatus {
  const _$SyncStatusImpl({
    this.state = SyncState.notInitialized,
    this.lastSyncTime,
    this.errorMessage,
    this.message,
    this.pendingItems = 0,
    this.retryCount = 0,
  });

  @override
  @JsonKey()
  final SyncState state;

  /// 最終同期日時
  @override
  final DateTime? lastSyncTime;

  /// エラーメッセージ（エラー時のみ）
  @override
  final String? errorMessage;

  /// 同期中のメッセージ（「データ読み込み中...」「データ移行中...」など）
  @override
  final String? message;

  /// 同期待ちのアイテム数
  @override
  @JsonKey()
  final int pendingItems;

  /// リトライ回数
  @override
  @JsonKey()
  final int retryCount;

  @override
  String toString() {
    return 'SyncStatus(state: $state, lastSyncTime: $lastSyncTime, errorMessage: $errorMessage, message: $message, pendingItems: $pendingItems, retryCount: $retryCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncStatusImpl &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.lastSyncTime, lastSyncTime) ||
                other.lastSyncTime == lastSyncTime) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.pendingItems, pendingItems) ||
                other.pendingItems == pendingItems) &&
            (identical(other.retryCount, retryCount) ||
                other.retryCount == retryCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    state,
    lastSyncTime,
    errorMessage,
    message,
    pendingItems,
    retryCount,
  );

  /// Create a copy of SyncStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncStatusImplCopyWith<_$SyncStatusImpl> get copyWith =>
      __$$SyncStatusImplCopyWithImpl<_$SyncStatusImpl>(this, _$identity);
}

abstract class _SyncStatus implements SyncStatus {
  const factory _SyncStatus({
    final SyncState state,
    final DateTime? lastSyncTime,
    final String? errorMessage,
    final String? message,
    final int pendingItems,
    final int retryCount,
  }) = _$SyncStatusImpl;

  @override
  SyncState get state;

  /// 最終同期日時
  @override
  DateTime? get lastSyncTime;

  /// エラーメッセージ（エラー時のみ）
  @override
  String? get errorMessage;

  /// 同期中のメッセージ（「データ読み込み中...」「データ移行中...」など）
  @override
  String? get message;

  /// 同期待ちのアイテム数
  @override
  int get pendingItems;

  /// リトライ回数
  @override
  int get retryCount;

  /// Create a copy of SyncStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncStatusImplCopyWith<_$SyncStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
