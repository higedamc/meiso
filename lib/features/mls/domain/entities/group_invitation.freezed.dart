// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_invitation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GroupInvitation {
  /// グループID
  String get groupId => throw _privateConstructorUsedError;

  /// グループ名
  String get groupName => throw _privateConstructorUsedError;

  /// Welcome Message（Base64エンコード）
  ///
  /// 招待者がMLS APIで生成したWelcome Message。
  /// 受諾時にこのメッセージを使用してグループに参加する。
  String get welcomeMessage => throw _privateConstructorUsedError;

  /// 招待者の公開鍵（hex形式）
  String get inviterPubkey => throw _privateConstructorUsedError;

  /// 招待者の名前（任意）
  String? get inviterName => throw _privateConstructorUsedError;

  /// 招待を受信した日時
  DateTime get receivedAt => throw _privateConstructorUsedError;

  /// ペンディング状態
  ///
  /// true: ユーザーがまだ受諾していない
  /// false: 受諾済み
  bool get isPending => throw _privateConstructorUsedError;

  /// 受諾日時（任意）
  DateTime? get acceptedAt => throw _privateConstructorUsedError;

  /// Create a copy of GroupInvitation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupInvitationCopyWith<GroupInvitation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupInvitationCopyWith<$Res> {
  factory $GroupInvitationCopyWith(
    GroupInvitation value,
    $Res Function(GroupInvitation) then,
  ) = _$GroupInvitationCopyWithImpl<$Res, GroupInvitation>;
  @useResult
  $Res call({
    String groupId,
    String groupName,
    String welcomeMessage,
    String inviterPubkey,
    String? inviterName,
    DateTime receivedAt,
    bool isPending,
    DateTime? acceptedAt,
  });
}

/// @nodoc
class _$GroupInvitationCopyWithImpl<$Res, $Val extends GroupInvitation>
    implements $GroupInvitationCopyWith<$Res> {
  _$GroupInvitationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupInvitation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? groupName = null,
    Object? welcomeMessage = null,
    Object? inviterPubkey = null,
    Object? inviterName = freezed,
    Object? receivedAt = null,
    Object? isPending = null,
    Object? acceptedAt = freezed,
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
            welcomeMessage: null == welcomeMessage
                ? _value.welcomeMessage
                : welcomeMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            inviterPubkey: null == inviterPubkey
                ? _value.inviterPubkey
                : inviterPubkey // ignore: cast_nullable_to_non_nullable
                      as String,
            inviterName: freezed == inviterName
                ? _value.inviterName
                : inviterName // ignore: cast_nullable_to_non_nullable
                      as String?,
            receivedAt: null == receivedAt
                ? _value.receivedAt
                : receivedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isPending: null == isPending
                ? _value.isPending
                : isPending // ignore: cast_nullable_to_non_nullable
                      as bool,
            acceptedAt: freezed == acceptedAt
                ? _value.acceptedAt
                : acceptedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupInvitationImplCopyWith<$Res>
    implements $GroupInvitationCopyWith<$Res> {
  factory _$$GroupInvitationImplCopyWith(
    _$GroupInvitationImpl value,
    $Res Function(_$GroupInvitationImpl) then,
  ) = __$$GroupInvitationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String groupName,
    String welcomeMessage,
    String inviterPubkey,
    String? inviterName,
    DateTime receivedAt,
    bool isPending,
    DateTime? acceptedAt,
  });
}

/// @nodoc
class __$$GroupInvitationImplCopyWithImpl<$Res>
    extends _$GroupInvitationCopyWithImpl<$Res, _$GroupInvitationImpl>
    implements _$$GroupInvitationImplCopyWith<$Res> {
  __$$GroupInvitationImplCopyWithImpl(
    _$GroupInvitationImpl _value,
    $Res Function(_$GroupInvitationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupInvitation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? groupName = null,
    Object? welcomeMessage = null,
    Object? inviterPubkey = null,
    Object? inviterName = freezed,
    Object? receivedAt = null,
    Object? isPending = null,
    Object? acceptedAt = freezed,
  }) {
    return _then(
      _$GroupInvitationImpl(
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        groupName: null == groupName
            ? _value.groupName
            : groupName // ignore: cast_nullable_to_non_nullable
                  as String,
        welcomeMessage: null == welcomeMessage
            ? _value.welcomeMessage
            : welcomeMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        inviterPubkey: null == inviterPubkey
            ? _value.inviterPubkey
            : inviterPubkey // ignore: cast_nullable_to_non_nullable
                  as String,
        inviterName: freezed == inviterName
            ? _value.inviterName
            : inviterName // ignore: cast_nullable_to_non_nullable
                  as String?,
        receivedAt: null == receivedAt
            ? _value.receivedAt
            : receivedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isPending: null == isPending
            ? _value.isPending
            : isPending // ignore: cast_nullable_to_non_nullable
                  as bool,
        acceptedAt: freezed == acceptedAt
            ? _value.acceptedAt
            : acceptedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$GroupInvitationImpl extends _GroupInvitation {
  const _$GroupInvitationImpl({
    required this.groupId,
    required this.groupName,
    required this.welcomeMessage,
    required this.inviterPubkey,
    this.inviterName,
    required this.receivedAt,
    required this.isPending,
    this.acceptedAt,
  }) : super._();

  /// グループID
  @override
  final String groupId;

  /// グループ名
  @override
  final String groupName;

  /// Welcome Message（Base64エンコード）
  ///
  /// 招待者がMLS APIで生成したWelcome Message。
  /// 受諾時にこのメッセージを使用してグループに参加する。
  @override
  final String welcomeMessage;

  /// 招待者の公開鍵（hex形式）
  @override
  final String inviterPubkey;

  /// 招待者の名前（任意）
  @override
  final String? inviterName;

  /// 招待を受信した日時
  @override
  final DateTime receivedAt;

  /// ペンディング状態
  ///
  /// true: ユーザーがまだ受諾していない
  /// false: 受諾済み
  @override
  final bool isPending;

  /// 受諾日時（任意）
  @override
  final DateTime? acceptedAt;

  @override
  String toString() {
    return 'GroupInvitation(groupId: $groupId, groupName: $groupName, welcomeMessage: $welcomeMessage, inviterPubkey: $inviterPubkey, inviterName: $inviterName, receivedAt: $receivedAt, isPending: $isPending, acceptedAt: $acceptedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupInvitationImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.welcomeMessage, welcomeMessage) ||
                other.welcomeMessage == welcomeMessage) &&
            (identical(other.inviterPubkey, inviterPubkey) ||
                other.inviterPubkey == inviterPubkey) &&
            (identical(other.inviterName, inviterName) ||
                other.inviterName == inviterName) &&
            (identical(other.receivedAt, receivedAt) ||
                other.receivedAt == receivedAt) &&
            (identical(other.isPending, isPending) ||
                other.isPending == isPending) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    groupId,
    groupName,
    welcomeMessage,
    inviterPubkey,
    inviterName,
    receivedAt,
    isPending,
    acceptedAt,
  );

  /// Create a copy of GroupInvitation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupInvitationImplCopyWith<_$GroupInvitationImpl> get copyWith =>
      __$$GroupInvitationImplCopyWithImpl<_$GroupInvitationImpl>(
        this,
        _$identity,
      );
}

abstract class _GroupInvitation extends GroupInvitation {
  const factory _GroupInvitation({
    required final String groupId,
    required final String groupName,
    required final String welcomeMessage,
    required final String inviterPubkey,
    final String? inviterName,
    required final DateTime receivedAt,
    required final bool isPending,
    final DateTime? acceptedAt,
  }) = _$GroupInvitationImpl;
  const _GroupInvitation._() : super._();

  /// グループID
  @override
  String get groupId;

  /// グループ名
  @override
  String get groupName;

  /// Welcome Message（Base64エンコード）
  ///
  /// 招待者がMLS APIで生成したWelcome Message。
  /// 受諾時にこのメッセージを使用してグループに参加する。
  @override
  String get welcomeMessage;

  /// 招待者の公開鍵（hex形式）
  @override
  String get inviterPubkey;

  /// 招待者の名前（任意）
  @override
  String? get inviterName;

  /// 招待を受信した日時
  @override
  DateTime get receivedAt;

  /// ペンディング状態
  ///
  /// true: ユーザーがまだ受諾していない
  /// false: 受諾済み
  @override
  bool get isPending;

  /// 受諾日時（任意）
  @override
  DateTime? get acceptedAt;

  /// Create a copy of GroupInvitation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupInvitationImplCopyWith<_$GroupInvitationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
