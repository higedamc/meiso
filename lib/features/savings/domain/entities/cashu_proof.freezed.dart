// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cashu_proof.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CashuProof _$CashuProofFromJson(Map<String, dynamic> json) {
  return _CashuProof.fromJson(json);
}

/// @nodoc
mixin _$CashuProof {
  /// keyset ID（どの mint / keyset の proof か）
  String get id => throw _privateConstructorUsedError;

  /// 額面（sat）。Cashu は 2 の冪の額面に分割される。
  int get amount => throw _privateConstructorUsedError;

  /// 秘密値（この proof の所有を証明する）。**秘密**
  String get secret => throw _privateConstructorUsedError;

  /// 署名（unblinded signature, 16進）
  String get C => throw _privateConstructorUsedError;

  /// この proof を保管している mint の URL
  String get mintUrl => throw _privateConstructorUsedError;

  /// Serializes this CashuProof to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CashuProof
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CashuProofCopyWith<CashuProof> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CashuProofCopyWith<$Res> {
  factory $CashuProofCopyWith(
    CashuProof value,
    $Res Function(CashuProof) then,
  ) = _$CashuProofCopyWithImpl<$Res, CashuProof>;
  @useResult
  $Res call({String id, int amount, String secret, String C, String mintUrl});
}

/// @nodoc
class _$CashuProofCopyWithImpl<$Res, $Val extends CashuProof>
    implements $CashuProofCopyWith<$Res> {
  _$CashuProofCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CashuProof
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? amount = null,
    Object? secret = null,
    Object? C = null,
    Object? mintUrl = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            secret: null == secret
                ? _value.secret
                : secret // ignore: cast_nullable_to_non_nullable
                      as String,
            C: null == C
                ? _value.C
                : C // ignore: cast_nullable_to_non_nullable
                      as String,
            mintUrl: null == mintUrl
                ? _value.mintUrl
                : mintUrl // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CashuProofImplCopyWith<$Res>
    implements $CashuProofCopyWith<$Res> {
  factory _$$CashuProofImplCopyWith(
    _$CashuProofImpl value,
    $Res Function(_$CashuProofImpl) then,
  ) = __$$CashuProofImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, int amount, String secret, String C, String mintUrl});
}

/// @nodoc
class __$$CashuProofImplCopyWithImpl<$Res>
    extends _$CashuProofCopyWithImpl<$Res, _$CashuProofImpl>
    implements _$$CashuProofImplCopyWith<$Res> {
  __$$CashuProofImplCopyWithImpl(
    _$CashuProofImpl _value,
    $Res Function(_$CashuProofImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CashuProof
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? amount = null,
    Object? secret = null,
    Object? C = null,
    Object? mintUrl = null,
  }) {
    return _then(
      _$CashuProofImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        secret: null == secret
            ? _value.secret
            : secret // ignore: cast_nullable_to_non_nullable
                  as String,
        C: null == C
            ? _value.C
            : C // ignore: cast_nullable_to_non_nullable
                  as String,
        mintUrl: null == mintUrl
            ? _value.mintUrl
            : mintUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CashuProofImpl extends _CashuProof {
  const _$CashuProofImpl({
    required this.id,
    required this.amount,
    required this.secret,
    required this.C,
    required this.mintUrl,
  }) : super._();

  factory _$CashuProofImpl.fromJson(Map<String, dynamic> json) =>
      _$$CashuProofImplFromJson(json);

  /// keyset ID（どの mint / keyset の proof か）
  @override
  final String id;

  /// 額面（sat）。Cashu は 2 の冪の額面に分割される。
  @override
  final int amount;

  /// 秘密値（この proof の所有を証明する）。**秘密**
  @override
  final String secret;

  /// 署名（unblinded signature, 16進）
  @override
  final String C;

  /// この proof を保管している mint の URL
  @override
  final String mintUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CashuProofImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.secret, secret) || other.secret == secret) &&
            (identical(other.C, C) || other.C == C) &&
            (identical(other.mintUrl, mintUrl) || other.mintUrl == mintUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, amount, secret, C, mintUrl);

  /// Create a copy of CashuProof
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CashuProofImplCopyWith<_$CashuProofImpl> get copyWith =>
      __$$CashuProofImplCopyWithImpl<_$CashuProofImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CashuProofImplToJson(this);
  }
}

abstract class _CashuProof extends CashuProof {
  const factory _CashuProof({
    required final String id,
    required final int amount,
    required final String secret,
    required final String C,
    required final String mintUrl,
  }) = _$CashuProofImpl;
  const _CashuProof._() : super._();

  factory _CashuProof.fromJson(Map<String, dynamic> json) =
      _$CashuProofImpl.fromJson;

  /// keyset ID（どの mint / keyset の proof か）
  @override
  String get id;

  /// 額面（sat）。Cashu は 2 の冪の額面に分割される。
  @override
  int get amount;

  /// 秘密値（この proof の所有を証明する）。**秘密**
  @override
  String get secret;

  /// 署名（unblinded signature, 16進）
  @override
  String get C;

  /// この proof を保管している mint の URL
  @override
  String get mintUrl;

  /// Create a copy of CashuProof
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CashuProofImplCopyWith<_$CashuProofImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
