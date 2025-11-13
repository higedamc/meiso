// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'key_package.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$KeyPackage {
  /// Key Package本体（Base64エンコード）
  String get keyPackage => throw _privateConstructorUsedError;

  /// 所有者の公開鍵（hex形式）
  String get ownerPubkey => throw _privateConstructorUsedError;

  /// 公開日時
  DateTime get publishedAt => throw _privateConstructorUsedError;

  /// NostrイベントID（任意）
  ///
  /// Kind 10443イベントとして公開された場合のイベントID
  String? get eventId => throw _privateConstructorUsedError;

  /// MLSプロトコルバージョン（任意）
  String? get mlsProtocolVersion => throw _privateConstructorUsedError;

  /// Ciphersuite（任意）
  String? get ciphersuite => throw _privateConstructorUsedError;

  /// Create a copy of KeyPackage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $KeyPackageCopyWith<KeyPackage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeyPackageCopyWith<$Res> {
  factory $KeyPackageCopyWith(
    KeyPackage value,
    $Res Function(KeyPackage) then,
  ) = _$KeyPackageCopyWithImpl<$Res, KeyPackage>;
  @useResult
  $Res call({
    String keyPackage,
    String ownerPubkey,
    DateTime publishedAt,
    String? eventId,
    String? mlsProtocolVersion,
    String? ciphersuite,
  });
}

/// @nodoc
class _$KeyPackageCopyWithImpl<$Res, $Val extends KeyPackage>
    implements $KeyPackageCopyWith<$Res> {
  _$KeyPackageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of KeyPackage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? keyPackage = null,
    Object? ownerPubkey = null,
    Object? publishedAt = null,
    Object? eventId = freezed,
    Object? mlsProtocolVersion = freezed,
    Object? ciphersuite = freezed,
  }) {
    return _then(
      _value.copyWith(
            keyPackage: null == keyPackage
                ? _value.keyPackage
                : keyPackage // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerPubkey: null == ownerPubkey
                ? _value.ownerPubkey
                : ownerPubkey // ignore: cast_nullable_to_non_nullable
                      as String,
            publishedAt: null == publishedAt
                ? _value.publishedAt
                : publishedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            eventId: freezed == eventId
                ? _value.eventId
                : eventId // ignore: cast_nullable_to_non_nullable
                      as String?,
            mlsProtocolVersion: freezed == mlsProtocolVersion
                ? _value.mlsProtocolVersion
                : mlsProtocolVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
            ciphersuite: freezed == ciphersuite
                ? _value.ciphersuite
                : ciphersuite // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$KeyPackageImplCopyWith<$Res>
    implements $KeyPackageCopyWith<$Res> {
  factory _$$KeyPackageImplCopyWith(
    _$KeyPackageImpl value,
    $Res Function(_$KeyPackageImpl) then,
  ) = __$$KeyPackageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String keyPackage,
    String ownerPubkey,
    DateTime publishedAt,
    String? eventId,
    String? mlsProtocolVersion,
    String? ciphersuite,
  });
}

/// @nodoc
class __$$KeyPackageImplCopyWithImpl<$Res>
    extends _$KeyPackageCopyWithImpl<$Res, _$KeyPackageImpl>
    implements _$$KeyPackageImplCopyWith<$Res> {
  __$$KeyPackageImplCopyWithImpl(
    _$KeyPackageImpl _value,
    $Res Function(_$KeyPackageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of KeyPackage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? keyPackage = null,
    Object? ownerPubkey = null,
    Object? publishedAt = null,
    Object? eventId = freezed,
    Object? mlsProtocolVersion = freezed,
    Object? ciphersuite = freezed,
  }) {
    return _then(
      _$KeyPackageImpl(
        keyPackage: null == keyPackage
            ? _value.keyPackage
            : keyPackage // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerPubkey: null == ownerPubkey
            ? _value.ownerPubkey
            : ownerPubkey // ignore: cast_nullable_to_non_nullable
                  as String,
        publishedAt: null == publishedAt
            ? _value.publishedAt
            : publishedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        eventId: freezed == eventId
            ? _value.eventId
            : eventId // ignore: cast_nullable_to_non_nullable
                  as String?,
        mlsProtocolVersion: freezed == mlsProtocolVersion
            ? _value.mlsProtocolVersion
            : mlsProtocolVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
        ciphersuite: freezed == ciphersuite
            ? _value.ciphersuite
            : ciphersuite // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$KeyPackageImpl extends _KeyPackage {
  const _$KeyPackageImpl({
    required this.keyPackage,
    required this.ownerPubkey,
    required this.publishedAt,
    this.eventId,
    this.mlsProtocolVersion,
    this.ciphersuite,
  }) : super._();

  /// Key Package本体（Base64エンコード）
  @override
  final String keyPackage;

  /// 所有者の公開鍵（hex形式）
  @override
  final String ownerPubkey;

  /// 公開日時
  @override
  final DateTime publishedAt;

  /// NostrイベントID（任意）
  ///
  /// Kind 10443イベントとして公開された場合のイベントID
  @override
  final String? eventId;

  /// MLSプロトコルバージョン（任意）
  @override
  final String? mlsProtocolVersion;

  /// Ciphersuite（任意）
  @override
  final String? ciphersuite;

  @override
  String toString() {
    return 'KeyPackage(keyPackage: $keyPackage, ownerPubkey: $ownerPubkey, publishedAt: $publishedAt, eventId: $eventId, mlsProtocolVersion: $mlsProtocolVersion, ciphersuite: $ciphersuite)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeyPackageImpl &&
            (identical(other.keyPackage, keyPackage) ||
                other.keyPackage == keyPackage) &&
            (identical(other.ownerPubkey, ownerPubkey) ||
                other.ownerPubkey == ownerPubkey) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.mlsProtocolVersion, mlsProtocolVersion) ||
                other.mlsProtocolVersion == mlsProtocolVersion) &&
            (identical(other.ciphersuite, ciphersuite) ||
                other.ciphersuite == ciphersuite));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    keyPackage,
    ownerPubkey,
    publishedAt,
    eventId,
    mlsProtocolVersion,
    ciphersuite,
  );

  /// Create a copy of KeyPackage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$KeyPackageImplCopyWith<_$KeyPackageImpl> get copyWith =>
      __$$KeyPackageImplCopyWithImpl<_$KeyPackageImpl>(this, _$identity);
}

abstract class _KeyPackage extends KeyPackage {
  const factory _KeyPackage({
    required final String keyPackage,
    required final String ownerPubkey,
    required final DateTime publishedAt,
    final String? eventId,
    final String? mlsProtocolVersion,
    final String? ciphersuite,
  }) = _$KeyPackageImpl;
  const _KeyPackage._() : super._();

  /// Key Package本体（Base64エンコード）
  @override
  String get keyPackage;

  /// 所有者の公開鍵（hex形式）
  @override
  String get ownerPubkey;

  /// 公開日時
  @override
  DateTime get publishedAt;

  /// NostrイベントID（任意）
  ///
  /// Kind 10443イベントとして公開された場合のイベントID
  @override
  String? get eventId;

  /// MLSプロトコルバージョン（任意）
  @override
  String? get mlsProtocolVersion;

  /// Ciphersuite（任意）
  @override
  String? get ciphersuite;

  /// Create a copy of KeyPackage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$KeyPackageImplCopyWith<_$KeyPackageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
