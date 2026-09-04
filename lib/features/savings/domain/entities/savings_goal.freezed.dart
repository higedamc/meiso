// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'savings_goal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SavingsGoal _$SavingsGoalFromJson(Map<String, dynamic> json) {
  return _SavingsGoal.fromJson(json);
}

/// @nodoc
mixin _$SavingsGoal {
  /// ゴールID（CustomList.id と対応。決定的に生成）
  String get goalId => throw _privateConstructorUsedError;

  /// ゴール名（表示用）
  String get name => throw _privateConstructorUsedError;

  /// 目標額（sat）
  int get targetSats => throw _privateConstructorUsedError;

  /// このゴールが ecash を保管する mint の URL
  String get mintUrl => throw _privateConstructorUsedError;

  /// 受取用 P2PK 公開鍵（hex）。
  /// 協同ゴールで NutZap を受け取る場合のみ必須。個人積立では null 可。
  String? get p2pkPubkey => throw _privateConstructorUsedError;

  /// 引き出し解禁の目安期日（UX ロック用）。null なら期日条件なし。
  DateTime? get deadline => throw _privateConstructorUsedError;

  /// 協同（共同貯金）かどうか。
  /// true のとき kind 10019 を公開し、メンバー/他者の NutZap を受け付ける。
  bool get isCollaborative => throw _privateConstructorUsedError;

  /// 作成日時
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// 単位通貨（現状 'sat' 固定。将来拡張用）
  String get currency => throw _privateConstructorUsedError;

  /// Serializes this SavingsGoal to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SavingsGoal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SavingsGoalCopyWith<SavingsGoal> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SavingsGoalCopyWith<$Res> {
  factory $SavingsGoalCopyWith(
    SavingsGoal value,
    $Res Function(SavingsGoal) then,
  ) = _$SavingsGoalCopyWithImpl<$Res, SavingsGoal>;
  @useResult
  $Res call({
    String goalId,
    String name,
    int targetSats,
    String mintUrl,
    String? p2pkPubkey,
    DateTime? deadline,
    bool isCollaborative,
    DateTime createdAt,
    String currency,
  });
}

/// @nodoc
class _$SavingsGoalCopyWithImpl<$Res, $Val extends SavingsGoal>
    implements $SavingsGoalCopyWith<$Res> {
  _$SavingsGoalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SavingsGoal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalId = null,
    Object? name = null,
    Object? targetSats = null,
    Object? mintUrl = null,
    Object? p2pkPubkey = freezed,
    Object? deadline = freezed,
    Object? isCollaborative = null,
    Object? createdAt = null,
    Object? currency = null,
  }) {
    return _then(
      _value.copyWith(
            goalId: null == goalId
                ? _value.goalId
                : goalId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            targetSats: null == targetSats
                ? _value.targetSats
                : targetSats // ignore: cast_nullable_to_non_nullable
                      as int,
            mintUrl: null == mintUrl
                ? _value.mintUrl
                : mintUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            p2pkPubkey: freezed == p2pkPubkey
                ? _value.p2pkPubkey
                : p2pkPubkey // ignore: cast_nullable_to_non_nullable
                      as String?,
            deadline: freezed == deadline
                ? _value.deadline
                : deadline // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isCollaborative: null == isCollaborative
                ? _value.isCollaborative
                : isCollaborative // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            currency: null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SavingsGoalImplCopyWith<$Res>
    implements $SavingsGoalCopyWith<$Res> {
  factory _$$SavingsGoalImplCopyWith(
    _$SavingsGoalImpl value,
    $Res Function(_$SavingsGoalImpl) then,
  ) = __$$SavingsGoalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String goalId,
    String name,
    int targetSats,
    String mintUrl,
    String? p2pkPubkey,
    DateTime? deadline,
    bool isCollaborative,
    DateTime createdAt,
    String currency,
  });
}

/// @nodoc
class __$$SavingsGoalImplCopyWithImpl<$Res>
    extends _$SavingsGoalCopyWithImpl<$Res, _$SavingsGoalImpl>
    implements _$$SavingsGoalImplCopyWith<$Res> {
  __$$SavingsGoalImplCopyWithImpl(
    _$SavingsGoalImpl _value,
    $Res Function(_$SavingsGoalImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SavingsGoal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalId = null,
    Object? name = null,
    Object? targetSats = null,
    Object? mintUrl = null,
    Object? p2pkPubkey = freezed,
    Object? deadline = freezed,
    Object? isCollaborative = null,
    Object? createdAt = null,
    Object? currency = null,
  }) {
    return _then(
      _$SavingsGoalImpl(
        goalId: null == goalId
            ? _value.goalId
            : goalId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        targetSats: null == targetSats
            ? _value.targetSats
            : targetSats // ignore: cast_nullable_to_non_nullable
                  as int,
        mintUrl: null == mintUrl
            ? _value.mintUrl
            : mintUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        p2pkPubkey: freezed == p2pkPubkey
            ? _value.p2pkPubkey
            : p2pkPubkey // ignore: cast_nullable_to_non_nullable
                  as String?,
        deadline: freezed == deadline
            ? _value.deadline
            : deadline // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isCollaborative: null == isCollaborative
            ? _value.isCollaborative
            : isCollaborative // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        currency: null == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SavingsGoalImpl implements _SavingsGoal {
  const _$SavingsGoalImpl({
    required this.goalId,
    required this.name,
    required this.targetSats,
    required this.mintUrl,
    this.p2pkPubkey,
    this.deadline,
    this.isCollaborative = false,
    required this.createdAt,
    this.currency = 'sat',
  });

  factory _$SavingsGoalImpl.fromJson(Map<String, dynamic> json) =>
      _$$SavingsGoalImplFromJson(json);

  /// ゴールID（CustomList.id と対応。決定的に生成）
  @override
  final String goalId;

  /// ゴール名（表示用）
  @override
  final String name;

  /// 目標額（sat）
  @override
  final int targetSats;

  /// このゴールが ecash を保管する mint の URL
  @override
  final String mintUrl;

  /// 受取用 P2PK 公開鍵（hex）。
  /// 協同ゴールで NutZap を受け取る場合のみ必須。個人積立では null 可。
  @override
  final String? p2pkPubkey;

  /// 引き出し解禁の目安期日（UX ロック用）。null なら期日条件なし。
  @override
  final DateTime? deadline;

  /// 協同（共同貯金）かどうか。
  /// true のとき kind 10019 を公開し、メンバー/他者の NutZap を受け付ける。
  @override
  @JsonKey()
  final bool isCollaborative;

  /// 作成日時
  @override
  final DateTime createdAt;

  /// 単位通貨（現状 'sat' 固定。将来拡張用）
  @override
  @JsonKey()
  final String currency;

  @override
  String toString() {
    return 'SavingsGoal(goalId: $goalId, name: $name, targetSats: $targetSats, mintUrl: $mintUrl, p2pkPubkey: $p2pkPubkey, deadline: $deadline, isCollaborative: $isCollaborative, createdAt: $createdAt, currency: $currency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SavingsGoalImpl &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.targetSats, targetSats) ||
                other.targetSats == targetSats) &&
            (identical(other.mintUrl, mintUrl) || other.mintUrl == mintUrl) &&
            (identical(other.p2pkPubkey, p2pkPubkey) ||
                other.p2pkPubkey == p2pkPubkey) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.isCollaborative, isCollaborative) ||
                other.isCollaborative == isCollaborative) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    goalId,
    name,
    targetSats,
    mintUrl,
    p2pkPubkey,
    deadline,
    isCollaborative,
    createdAt,
    currency,
  );

  /// Create a copy of SavingsGoal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SavingsGoalImplCopyWith<_$SavingsGoalImpl> get copyWith =>
      __$$SavingsGoalImplCopyWithImpl<_$SavingsGoalImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SavingsGoalImplToJson(this);
  }
}

abstract class _SavingsGoal implements SavingsGoal {
  const factory _SavingsGoal({
    required final String goalId,
    required final String name,
    required final int targetSats,
    required final String mintUrl,
    final String? p2pkPubkey,
    final DateTime? deadline,
    final bool isCollaborative,
    required final DateTime createdAt,
    final String currency,
  }) = _$SavingsGoalImpl;

  factory _SavingsGoal.fromJson(Map<String, dynamic> json) =
      _$SavingsGoalImpl.fromJson;

  /// ゴールID（CustomList.id と対応。決定的に生成）
  @override
  String get goalId;

  /// ゴール名（表示用）
  @override
  String get name;

  /// 目標額（sat）
  @override
  int get targetSats;

  /// このゴールが ecash を保管する mint の URL
  @override
  String get mintUrl;

  /// 受取用 P2PK 公開鍵（hex）。
  /// 協同ゴールで NutZap を受け取る場合のみ必須。個人積立では null 可。
  @override
  String? get p2pkPubkey;

  /// 引き出し解禁の目安期日（UX ロック用）。null なら期日条件なし。
  @override
  DateTime? get deadline;

  /// 協同（共同貯金）かどうか。
  /// true のとき kind 10019 を公開し、メンバー/他者の NutZap を受け付ける。
  @override
  bool get isCollaborative;

  /// 作成日時
  @override
  DateTime get createdAt;

  /// 単位通貨（現状 'sat' 固定。将来拡張用）
  @override
  String get currency;

  /// Create a copy of SavingsGoal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SavingsGoalImplCopyWith<_$SavingsGoalImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
