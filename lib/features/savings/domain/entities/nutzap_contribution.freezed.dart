// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nutzap_contribution.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NutzapContribution _$NutzapContributionFromJson(Map<String, dynamic> json) {
  return _NutzapContribution.fromJson(json);
}

/// @nodoc
mixin _$NutzapContribution {
  /// 元となった kind 9321 イベントID（重複回収防止のキー）
  String get eventId => throw _privateConstructorUsedError;

  /// 貢献先ゴールID
  String get goalId => throw _privateConstructorUsedError;

  /// 額面（sat）
  int get amountSats => throw _privateConstructorUsedError;

  /// 送り主の公開鍵（hex）
  String get senderPubkey => throw _privateConstructorUsedError;

  /// 任意のメッセージ（NutZap の content）
  String? get comment => throw _privateConstructorUsedError;

  /// 回収（自分のウォレットへ swap）した日時
  DateTime get redeemedAt => throw _privateConstructorUsedError;

  /// Serializes this NutzapContribution to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NutzapContribution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NutzapContributionCopyWith<NutzapContribution> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NutzapContributionCopyWith<$Res> {
  factory $NutzapContributionCopyWith(
    NutzapContribution value,
    $Res Function(NutzapContribution) then,
  ) = _$NutzapContributionCopyWithImpl<$Res, NutzapContribution>;
  @useResult
  $Res call({
    String eventId,
    String goalId,
    int amountSats,
    String senderPubkey,
    String? comment,
    DateTime redeemedAt,
  });
}

/// @nodoc
class _$NutzapContributionCopyWithImpl<$Res, $Val extends NutzapContribution>
    implements $NutzapContributionCopyWith<$Res> {
  _$NutzapContributionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NutzapContribution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventId = null,
    Object? goalId = null,
    Object? amountSats = null,
    Object? senderPubkey = null,
    Object? comment = freezed,
    Object? redeemedAt = null,
  }) {
    return _then(
      _value.copyWith(
            eventId: null == eventId
                ? _value.eventId
                : eventId // ignore: cast_nullable_to_non_nullable
                      as String,
            goalId: null == goalId
                ? _value.goalId
                : goalId // ignore: cast_nullable_to_non_nullable
                      as String,
            amountSats: null == amountSats
                ? _value.amountSats
                : amountSats // ignore: cast_nullable_to_non_nullable
                      as int,
            senderPubkey: null == senderPubkey
                ? _value.senderPubkey
                : senderPubkey // ignore: cast_nullable_to_non_nullable
                      as String,
            comment: freezed == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String?,
            redeemedAt: null == redeemedAt
                ? _value.redeemedAt
                : redeemedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NutzapContributionImplCopyWith<$Res>
    implements $NutzapContributionCopyWith<$Res> {
  factory _$$NutzapContributionImplCopyWith(
    _$NutzapContributionImpl value,
    $Res Function(_$NutzapContributionImpl) then,
  ) = __$$NutzapContributionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String eventId,
    String goalId,
    int amountSats,
    String senderPubkey,
    String? comment,
    DateTime redeemedAt,
  });
}

/// @nodoc
class __$$NutzapContributionImplCopyWithImpl<$Res>
    extends _$NutzapContributionCopyWithImpl<$Res, _$NutzapContributionImpl>
    implements _$$NutzapContributionImplCopyWith<$Res> {
  __$$NutzapContributionImplCopyWithImpl(
    _$NutzapContributionImpl _value,
    $Res Function(_$NutzapContributionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NutzapContribution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventId = null,
    Object? goalId = null,
    Object? amountSats = null,
    Object? senderPubkey = null,
    Object? comment = freezed,
    Object? redeemedAt = null,
  }) {
    return _then(
      _$NutzapContributionImpl(
        eventId: null == eventId
            ? _value.eventId
            : eventId // ignore: cast_nullable_to_non_nullable
                  as String,
        goalId: null == goalId
            ? _value.goalId
            : goalId // ignore: cast_nullable_to_non_nullable
                  as String,
        amountSats: null == amountSats
            ? _value.amountSats
            : amountSats // ignore: cast_nullable_to_non_nullable
                  as int,
        senderPubkey: null == senderPubkey
            ? _value.senderPubkey
            : senderPubkey // ignore: cast_nullable_to_non_nullable
                  as String,
        comment: freezed == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
        redeemedAt: null == redeemedAt
            ? _value.redeemedAt
            : redeemedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NutzapContributionImpl implements _NutzapContribution {
  const _$NutzapContributionImpl({
    required this.eventId,
    required this.goalId,
    required this.amountSats,
    required this.senderPubkey,
    this.comment,
    required this.redeemedAt,
  });

  factory _$NutzapContributionImpl.fromJson(Map<String, dynamic> json) =>
      _$$NutzapContributionImplFromJson(json);

  /// 元となった kind 9321 イベントID（重複回収防止のキー）
  @override
  final String eventId;

  /// 貢献先ゴールID
  @override
  final String goalId;

  /// 額面（sat）
  @override
  final int amountSats;

  /// 送り主の公開鍵（hex）
  @override
  final String senderPubkey;

  /// 任意のメッセージ（NutZap の content）
  @override
  final String? comment;

  /// 回収（自分のウォレットへ swap）した日時
  @override
  final DateTime redeemedAt;

  @override
  String toString() {
    return 'NutzapContribution(eventId: $eventId, goalId: $goalId, amountSats: $amountSats, senderPubkey: $senderPubkey, comment: $comment, redeemedAt: $redeemedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NutzapContributionImpl &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.amountSats, amountSats) ||
                other.amountSats == amountSats) &&
            (identical(other.senderPubkey, senderPubkey) ||
                other.senderPubkey == senderPubkey) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.redeemedAt, redeemedAt) ||
                other.redeemedAt == redeemedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    eventId,
    goalId,
    amountSats,
    senderPubkey,
    comment,
    redeemedAt,
  );

  /// Create a copy of NutzapContribution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NutzapContributionImplCopyWith<_$NutzapContributionImpl> get copyWith =>
      __$$NutzapContributionImplCopyWithImpl<_$NutzapContributionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NutzapContributionImplToJson(this);
  }
}

abstract class _NutzapContribution implements NutzapContribution {
  const factory _NutzapContribution({
    required final String eventId,
    required final String goalId,
    required final int amountSats,
    required final String senderPubkey,
    final String? comment,
    required final DateTime redeemedAt,
  }) = _$NutzapContributionImpl;

  factory _NutzapContribution.fromJson(Map<String, dynamic> json) =
      _$NutzapContributionImpl.fromJson;

  /// 元となった kind 9321 イベントID（重複回収防止のキー）
  @override
  String get eventId;

  /// 貢献先ゴールID
  @override
  String get goalId;

  /// 額面（sat）
  @override
  int get amountSats;

  /// 送り主の公開鍵（hex）
  @override
  String get senderPubkey;

  /// 任意のメッセージ（NutZap の content）
  @override
  String? get comment;

  /// 回収（自分のウォレットへ swap）した日時
  @override
  DateTime get redeemedAt;

  /// Create a copy of NutzapContribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NutzapContributionImplCopyWith<_$NutzapContributionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
