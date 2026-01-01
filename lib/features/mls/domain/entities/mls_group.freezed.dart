// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mls_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MlsGroup {
  /// グループID（UUID v4）
  String get groupId => throw _privateConstructorUsedError;

  /// グループ名
  String get groupName => throw _privateConstructorUsedError;

  /// グループメンバーの公開鍵リスト（hex形式）
  List<String> get memberPubkeys => throw _privateConstructorUsedError;

  /// Welcome Message（Base64エンコード）
  ///
  /// 招待時に生成され、新メンバーに送信される。
  /// 新メンバーはこのWelcome Messageを使用してグループに参加する。
  String? get welcomeMessage => throw _privateConstructorUsedError;

  /// 作成日時
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// 更新日時
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of MlsGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MlsGroupCopyWith<MlsGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MlsGroupCopyWith<$Res> {
  factory $MlsGroupCopyWith(MlsGroup value, $Res Function(MlsGroup) then) =
      _$MlsGroupCopyWithImpl<$Res, MlsGroup>;
  @useResult
  $Res call({
    String groupId,
    String groupName,
    List<String> memberPubkeys,
    String? welcomeMessage,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$MlsGroupCopyWithImpl<$Res, $Val extends MlsGroup>
    implements $MlsGroupCopyWith<$Res> {
  _$MlsGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MlsGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? groupName = null,
    Object? memberPubkeys = null,
    Object? welcomeMessage = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
            groupName: null == groupName
                ? _value.groupName
                : groupName // ignore: cast_nullable_to_non_nullable
                      as String,
            memberPubkeys: null == memberPubkeys
                ? _value.memberPubkeys
                : memberPubkeys // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            welcomeMessage: freezed == welcomeMessage
                ? _value.welcomeMessage
                : welcomeMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MlsGroupImplCopyWith<$Res>
    implements $MlsGroupCopyWith<$Res> {
  factory _$$MlsGroupImplCopyWith(
    _$MlsGroupImpl value,
    $Res Function(_$MlsGroupImpl) then,
  ) = __$$MlsGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String groupName,
    List<String> memberPubkeys,
    String? welcomeMessage,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$MlsGroupImplCopyWithImpl<$Res>
    extends _$MlsGroupCopyWithImpl<$Res, _$MlsGroupImpl>
    implements _$$MlsGroupImplCopyWith<$Res> {
  __$$MlsGroupImplCopyWithImpl(
    _$MlsGroupImpl _value,
    $Res Function(_$MlsGroupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MlsGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? groupName = null,
    Object? memberPubkeys = null,
    Object? welcomeMessage = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$MlsGroupImpl(
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        groupName: null == groupName
            ? _value.groupName
            : groupName // ignore: cast_nullable_to_non_nullable
                  as String,
        memberPubkeys: null == memberPubkeys
            ? _value._memberPubkeys
            : memberPubkeys // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        welcomeMessage: freezed == welcomeMessage
            ? _value.welcomeMessage
            : welcomeMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$MlsGroupImpl extends _MlsGroup {
  const _$MlsGroupImpl({
    required this.groupId,
    required this.groupName,
    required final List<String> memberPubkeys,
    this.welcomeMessage,
    required this.createdAt,
    required this.updatedAt,
  }) : _memberPubkeys = memberPubkeys,
       super._();

  /// グループID（UUID v4）
  @override
  final String groupId;

  /// グループ名
  @override
  final String groupName;

  /// グループメンバーの公開鍵リスト（hex形式）
  final List<String> _memberPubkeys;

  /// グループメンバーの公開鍵リスト（hex形式）
  @override
  List<String> get memberPubkeys {
    if (_memberPubkeys is EqualUnmodifiableListView) return _memberPubkeys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberPubkeys);
  }

  /// Welcome Message（Base64エンコード）
  ///
  /// 招待時に生成され、新メンバーに送信される。
  /// 新メンバーはこのWelcome Messageを使用してグループに参加する。
  @override
  final String? welcomeMessage;

  /// 作成日時
  @override
  final DateTime createdAt;

  /// 更新日時
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'MlsGroup(groupId: $groupId, groupName: $groupName, memberPubkeys: $memberPubkeys, welcomeMessage: $welcomeMessage, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MlsGroupImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            const DeepCollectionEquality().equals(
              other._memberPubkeys,
              _memberPubkeys,
            ) &&
            (identical(other.welcomeMessage, welcomeMessage) ||
                other.welcomeMessage == welcomeMessage) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    groupId,
    groupName,
    const DeepCollectionEquality().hash(_memberPubkeys),
    welcomeMessage,
    createdAt,
    updatedAt,
  );

  /// Create a copy of MlsGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MlsGroupImplCopyWith<_$MlsGroupImpl> get copyWith =>
      __$$MlsGroupImplCopyWithImpl<_$MlsGroupImpl>(this, _$identity);
}

abstract class _MlsGroup extends MlsGroup {
  const factory _MlsGroup({
    required final String groupId,
    required final String groupName,
    required final List<String> memberPubkeys,
    final String? welcomeMessage,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$MlsGroupImpl;
  const _MlsGroup._() : super._();

  /// グループID（UUID v4）
  @override
  String get groupId;

  /// グループ名
  @override
  String get groupName;

  /// グループメンバーの公開鍵リスト（hex形式）
  @override
  List<String> get memberPubkeys;

  /// Welcome Message（Base64エンコード）
  ///
  /// 招待時に生成され、新メンバーに送信される。
  /// 新メンバーはこのWelcome Messageを使用してグループに参加する。
  @override
  String? get welcomeMessage;

  /// 作成日時
  @override
  DateTime get createdAt;

  /// 更新日時
  @override
  DateTime get updatedAt;

  /// Create a copy of MlsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MlsGroupImplCopyWith<_$MlsGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
