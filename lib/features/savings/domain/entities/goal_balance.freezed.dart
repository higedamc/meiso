// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_balance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GoalBalance _$GoalBalanceFromJson(Map<String, dynamic> json) {
  return _GoalBalance.fromJson(json);
}

/// @nodoc
mixin _$GoalBalance {
  /// 対象ゴールID
  String get goalId => throw _privateConstructorUsedError;

  /// 現在の貯金額（未使用 proof 合計, sat）
  int get currentSats => throw _privateConstructorUsedError;

  /// 目標額（sat）
  int get targetSats => throw _privateConstructorUsedError;

  /// Serializes this GoalBalance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GoalBalance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GoalBalanceCopyWith<GoalBalance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GoalBalanceCopyWith<$Res> {
  factory $GoalBalanceCopyWith(
    GoalBalance value,
    $Res Function(GoalBalance) then,
  ) = _$GoalBalanceCopyWithImpl<$Res, GoalBalance>;
  @useResult
  $Res call({String goalId, int currentSats, int targetSats});
}

/// @nodoc
class _$GoalBalanceCopyWithImpl<$Res, $Val extends GoalBalance>
    implements $GoalBalanceCopyWith<$Res> {
  _$GoalBalanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GoalBalance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalId = null,
    Object? currentSats = null,
    Object? targetSats = null,
  }) {
    return _then(
      _value.copyWith(
            goalId: null == goalId
                ? _value.goalId
                : goalId // ignore: cast_nullable_to_non_nullable
                      as String,
            currentSats: null == currentSats
                ? _value.currentSats
                : currentSats // ignore: cast_nullable_to_non_nullable
                      as int,
            targetSats: null == targetSats
                ? _value.targetSats
                : targetSats // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GoalBalanceImplCopyWith<$Res>
    implements $GoalBalanceCopyWith<$Res> {
  factory _$$GoalBalanceImplCopyWith(
    _$GoalBalanceImpl value,
    $Res Function(_$GoalBalanceImpl) then,
  ) = __$$GoalBalanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String goalId, int currentSats, int targetSats});
}

/// @nodoc
class __$$GoalBalanceImplCopyWithImpl<$Res>
    extends _$GoalBalanceCopyWithImpl<$Res, _$GoalBalanceImpl>
    implements _$$GoalBalanceImplCopyWith<$Res> {
  __$$GoalBalanceImplCopyWithImpl(
    _$GoalBalanceImpl _value,
    $Res Function(_$GoalBalanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GoalBalance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalId = null,
    Object? currentSats = null,
    Object? targetSats = null,
  }) {
    return _then(
      _$GoalBalanceImpl(
        goalId: null == goalId
            ? _value.goalId
            : goalId // ignore: cast_nullable_to_non_nullable
                  as String,
        currentSats: null == currentSats
            ? _value.currentSats
            : currentSats // ignore: cast_nullable_to_non_nullable
                  as int,
        targetSats: null == targetSats
            ? _value.targetSats
            : targetSats // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GoalBalanceImpl extends _GoalBalance {
  const _$GoalBalanceImpl({
    required this.goalId,
    required this.currentSats,
    required this.targetSats,
  }) : super._();

  factory _$GoalBalanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$GoalBalanceImplFromJson(json);

  /// 対象ゴールID
  @override
  final String goalId;

  /// 現在の貯金額（未使用 proof 合計, sat）
  @override
  final int currentSats;

  /// 目標額（sat）
  @override
  final int targetSats;

  @override
  String toString() {
    return 'GoalBalance(goalId: $goalId, currentSats: $currentSats, targetSats: $targetSats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GoalBalanceImpl &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.currentSats, currentSats) ||
                other.currentSats == currentSats) &&
            (identical(other.targetSats, targetSats) ||
                other.targetSats == targetSats));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, goalId, currentSats, targetSats);

  /// Create a copy of GoalBalance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GoalBalanceImplCopyWith<_$GoalBalanceImpl> get copyWith =>
      __$$GoalBalanceImplCopyWithImpl<_$GoalBalanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GoalBalanceImplToJson(this);
  }
}

abstract class _GoalBalance extends GoalBalance {
  const factory _GoalBalance({
    required final String goalId,
    required final int currentSats,
    required final int targetSats,
  }) = _$GoalBalanceImpl;
  const _GoalBalance._() : super._();

  factory _GoalBalance.fromJson(Map<String, dynamic> json) =
      _$GoalBalanceImpl.fromJson;

  /// 対象ゴールID
  @override
  String get goalId;

  /// 現在の貯金額（未使用 proof 合計, sat）
  @override
  int get currentSats;

  /// 目標額（sat）
  @override
  int get targetSats;

  /// Create a copy of GoalBalance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GoalBalanceImplCopyWith<_$GoalBalanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
