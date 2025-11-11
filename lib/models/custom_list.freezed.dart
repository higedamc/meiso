// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'custom_list.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CustomList _$CustomListFromJson(Map<String, dynamic> json) {
  return _CustomList.fromJson(json);
}

/// @nodoc
mixin _$CustomList {
  /// UUID
  String get id => throw _privateConstructorUsedError;

  /// リスト名
  String get name => throw _privateConstructorUsedError;

  /// 並び順
  int get order => throw _privateConstructorUsedError;

  /// 作成日時
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// 更新日時
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// グループリストかどうか（マルチパーティ暗号化使用）
  bool get isGroup => throw _privateConstructorUsedError;

  /// グループメンバーの公開鍵リスト（hex形式）
  List<String> get groupMembers => throw _privateConstructorUsedError;

  /// インビテーション待ちかどうか（Phase 6.4: MLS招待システム）
  bool get isPendingInvitation => throw _privateConstructorUsedError;

  /// 招待者のnpub（Phase 6.4: MLS招待システム）
  String? get inviterNpub => throw _privateConstructorUsedError;

  /// 招待者の名前（Phase 6.4: MLS招待システム）
  String? get inviterName => throw _privateConstructorUsedError;

  /// Welcome Message（base64エンコード済み）（Phase 6.4: MLS招待システム）
  String? get welcomeMsg => throw _privateConstructorUsedError;

  /// Serializes this CustomList to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CustomList
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CustomListCopyWith<CustomList> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CustomListCopyWith<$Res> {
  factory $CustomListCopyWith(
    CustomList value,
    $Res Function(CustomList) then,
  ) = _$CustomListCopyWithImpl<$Res, CustomList>;
  @useResult
  $Res call({
    String id,
    String name,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    bool isGroup,
    List<String> groupMembers,
    bool isPendingInvitation,
    String? inviterNpub,
    String? inviterName,
    String? welcomeMsg,
  });
}

/// @nodoc
class _$CustomListCopyWithImpl<$Res, $Val extends CustomList>
    implements $CustomListCopyWith<$Res> {
  _$CustomListCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CustomList
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? order = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isGroup = null,
    Object? groupMembers = null,
    Object? isPendingInvitation = null,
    Object? inviterNpub = freezed,
    Object? inviterName = freezed,
    Object? welcomeMsg = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
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
            isGroup: null == isGroup
                ? _value.isGroup
                : isGroup // ignore: cast_nullable_to_non_nullable
                      as bool,
            groupMembers: null == groupMembers
                ? _value.groupMembers
                : groupMembers // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isPendingInvitation: null == isPendingInvitation
                ? _value.isPendingInvitation
                : isPendingInvitation // ignore: cast_nullable_to_non_nullable
                      as bool,
            inviterNpub: freezed == inviterNpub
                ? _value.inviterNpub
                : inviterNpub // ignore: cast_nullable_to_non_nullable
                      as String?,
            inviterName: freezed == inviterName
                ? _value.inviterName
                : inviterName // ignore: cast_nullable_to_non_nullable
                      as String?,
            welcomeMsg: freezed == welcomeMsg
                ? _value.welcomeMsg
                : welcomeMsg // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CustomListImplCopyWith<$Res>
    implements $CustomListCopyWith<$Res> {
  factory _$$CustomListImplCopyWith(
    _$CustomListImpl value,
    $Res Function(_$CustomListImpl) then,
  ) = __$$CustomListImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    int order,
    DateTime createdAt,
    DateTime updatedAt,
    bool isGroup,
    List<String> groupMembers,
    bool isPendingInvitation,
    String? inviterNpub,
    String? inviterName,
    String? welcomeMsg,
  });
}

/// @nodoc
class __$$CustomListImplCopyWithImpl<$Res>
    extends _$CustomListCopyWithImpl<$Res, _$CustomListImpl>
    implements _$$CustomListImplCopyWith<$Res> {
  __$$CustomListImplCopyWithImpl(
    _$CustomListImpl _value,
    $Res Function(_$CustomListImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CustomList
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? order = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isGroup = null,
    Object? groupMembers = null,
    Object? isPendingInvitation = null,
    Object? inviterNpub = freezed,
    Object? inviterName = freezed,
    Object? welcomeMsg = freezed,
  }) {
    return _then(
      _$CustomListImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
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
        isGroup: null == isGroup
            ? _value.isGroup
            : isGroup // ignore: cast_nullable_to_non_nullable
                  as bool,
        groupMembers: null == groupMembers
            ? _value.groupMembers
            : groupMembers // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isPendingInvitation: null == isPendingInvitation
            ? _value.isPendingInvitation
            : isPendingInvitation // ignore: cast_nullable_to_non_nullable
                  as bool,
        inviterNpub: freezed == inviterNpub
            ? _value.inviterNpub
            : inviterNpub // ignore: cast_nullable_to_non_nullable
                  as String?,
        inviterName: freezed == inviterName
            ? _value.inviterName
            : inviterName // ignore: cast_nullable_to_non_nullable
                  as String?,
        welcomeMsg: freezed == welcomeMsg
            ? _value.welcomeMsg
            : welcomeMsg // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CustomListImpl implements _CustomList {
  const _$CustomListImpl({
    required this.id,
    required this.name,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isGroup = false,
    this.groupMembers = const [],
    this.isPendingInvitation = false,
    this.inviterNpub,
    this.inviterName,
    this.welcomeMsg,
  });

  factory _$CustomListImpl.fromJson(Map<String, dynamic> json) =>
      _$$CustomListImplFromJson(json);

  /// UUID
  @override
  final String id;

  /// リスト名
  @override
  final String name;

  /// 並び順
  @override
  @JsonKey()
  final int order;

  /// 作成日時
  @override
  final DateTime createdAt;

  /// 更新日時
  @override
  final DateTime updatedAt;

  /// グループリストかどうか（マルチパーティ暗号化使用）
  @override
  @JsonKey()
  final bool isGroup;

  /// グループメンバーの公開鍵リスト（hex形式）
  @override
  @JsonKey()
  final List<String> groupMembers;

  /// インビテーション待ちかどうか（Phase 6.4: MLS招待システム）
  @override
  @JsonKey()
  final bool isPendingInvitation;

  /// 招待者のnpub（Phase 6.4: MLS招待システム）
  @override
  final String? inviterNpub;

  /// 招待者の名前（Phase 6.4: MLS招待システム）
  @override
  final String? inviterName;

  /// Welcome Message（base64エンコード済み）（Phase 6.4: MLS招待システム）
  @override
  final String? welcomeMsg;

  @override
  String toString() {
    return 'CustomList(id: $id, name: $name, order: $order, createdAt: $createdAt, updatedAt: $updatedAt, isGroup: $isGroup, groupMembers: $groupMembers, isPendingInvitation: $isPendingInvitation, inviterNpub: $inviterNpub, inviterName: $inviterName, welcomeMsg: $welcomeMsg)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomListImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.isGroup, isGroup) || other.isGroup == isGroup) &&
            const DeepCollectionEquality().equals(
              other.groupMembers,
              groupMembers,
            ) &&
            (identical(other.isPendingInvitation, isPendingInvitation) ||
                other.isPendingInvitation == isPendingInvitation) &&
            (identical(other.inviterNpub, inviterNpub) ||
                other.inviterNpub == inviterNpub) &&
            (identical(other.inviterName, inviterName) ||
                other.inviterName == inviterName) &&
            (identical(other.welcomeMsg, welcomeMsg) ||
                other.welcomeMsg == welcomeMsg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    order,
    createdAt,
    updatedAt,
    isGroup,
    const DeepCollectionEquality().hash(groupMembers),
    isPendingInvitation,
    inviterNpub,
    inviterName,
    welcomeMsg,
  );

  /// Create a copy of CustomList
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomListImplCopyWith<_$CustomListImpl> get copyWith =>
      __$$CustomListImplCopyWithImpl<_$CustomListImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CustomListImplToJson(this);
  }
}

abstract class _CustomList implements CustomList {
  const factory _CustomList({
    required final String id,
    required final String name,
    final int order,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final bool isGroup,
    final List<String> groupMembers,
    final bool isPendingInvitation,
    final String? inviterNpub,
    final String? inviterName,
    final String? welcomeMsg,
  }) = _$CustomListImpl;

  factory _CustomList.fromJson(Map<String, dynamic> json) =
      _$CustomListImpl.fromJson;

  /// UUID
  @override
  String get id;

  /// リスト名
  @override
  String get name;

  /// 並び順
  @override
  int get order;

  /// 作成日時
  @override
  DateTime get createdAt;

  /// 更新日時
  @override
  DateTime get updatedAt;

  /// グループリストかどうか（マルチパーティ暗号化使用）
  @override
  bool get isGroup;

  /// グループメンバーの公開鍵リスト（hex形式）
  @override
  List<String> get groupMembers;

  /// インビテーション待ちかどうか（Phase 6.4: MLS招待システム）
  @override
  bool get isPendingInvitation;

  /// 招待者のnpub（Phase 6.4: MLS招待システム）
  @override
  String? get inviterNpub;

  /// 招待者の名前（Phase 6.4: MLS招待システム）
  @override
  String? get inviterName;

  /// Welcome Message（base64エンコード済み）（Phase 6.4: MLS招待システム）
  @override
  String? get welcomeMsg;

  /// Create a copy of CustomList
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CustomListImplCopyWith<_$CustomListImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
