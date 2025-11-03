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

  @override
  String toString() {
    return 'CustomList(id: $id, name: $name, order: $order, createdAt: $createdAt, updatedAt: $updatedAt)';
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
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, order, createdAt, updatedAt);

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

  /// Create a copy of CustomList
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CustomListImplCopyWith<_$CustomListImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
