// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurrence_pattern.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecurrencePattern _$RecurrencePatternFromJson(Map<String, dynamic> json) {
  return _RecurrencePattern.fromJson(json);
}

/// @nodoc
mixin _$RecurrencePattern {
  /// 繰り返しタイプ
  RecurrenceType get type => throw _privateConstructorUsedError;

  /// 繰り返し間隔 (例: 2 = 2日ごと、2週間ごと)
  int get interval => throw _privateConstructorUsedError;

  /// 週単位の繰り返しで使用する曜日リスト
  /// 1=月曜, 2=火曜, ..., 7=日曜
  /// 例: [1, 3, 5] = 月・水・金
  List<int>? get weekdays => throw _privateConstructorUsedError;

  /// 月単位の繰り返しで使用する日
  /// 1-31 または null (日付がない月はスキップ)
  int? get dayOfMonth => throw _privateConstructorUsedError;

  /// 繰り返し終了日 (null = 無期限)
  DateTime? get endDate => throw _privateConstructorUsedError;

  /// Serializes this RecurrencePattern to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecurrencePatternCopyWith<RecurrencePattern> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurrencePatternCopyWith<$Res> {
  factory $RecurrencePatternCopyWith(
    RecurrencePattern value,
    $Res Function(RecurrencePattern) then,
  ) = _$RecurrencePatternCopyWithImpl<$Res, RecurrencePattern>;
  @useResult
  $Res call({
    RecurrenceType type,
    int interval,
    List<int>? weekdays,
    int? dayOfMonth,
    DateTime? endDate,
  });
}

/// @nodoc
class _$RecurrencePatternCopyWithImpl<$Res, $Val extends RecurrencePattern>
    implements $RecurrencePatternCopyWith<$Res> {
  _$RecurrencePatternCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? interval = null,
    Object? weekdays = freezed,
    Object? dayOfMonth = freezed,
    Object? endDate = freezed,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as RecurrenceType,
            interval: null == interval
                ? _value.interval
                : interval // ignore: cast_nullable_to_non_nullable
                      as int,
            weekdays: freezed == weekdays
                ? _value.weekdays
                : weekdays // ignore: cast_nullable_to_non_nullable
                      as List<int>?,
            dayOfMonth: freezed == dayOfMonth
                ? _value.dayOfMonth
                : dayOfMonth // ignore: cast_nullable_to_non_nullable
                      as int?,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecurrencePatternImplCopyWith<$Res>
    implements $RecurrencePatternCopyWith<$Res> {
  factory _$$RecurrencePatternImplCopyWith(
    _$RecurrencePatternImpl value,
    $Res Function(_$RecurrencePatternImpl) then,
  ) = __$$RecurrencePatternImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    RecurrenceType type,
    int interval,
    List<int>? weekdays,
    int? dayOfMonth,
    DateTime? endDate,
  });
}

/// @nodoc
class __$$RecurrencePatternImplCopyWithImpl<$Res>
    extends _$RecurrencePatternCopyWithImpl<$Res, _$RecurrencePatternImpl>
    implements _$$RecurrencePatternImplCopyWith<$Res> {
  __$$RecurrencePatternImplCopyWithImpl(
    _$RecurrencePatternImpl _value,
    $Res Function(_$RecurrencePatternImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? interval = null,
    Object? weekdays = freezed,
    Object? dayOfMonth = freezed,
    Object? endDate = freezed,
  }) {
    return _then(
      _$RecurrencePatternImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as RecurrenceType,
        interval: null == interval
            ? _value.interval
            : interval // ignore: cast_nullable_to_non_nullable
                  as int,
        weekdays: freezed == weekdays
            ? _value._weekdays
            : weekdays // ignore: cast_nullable_to_non_nullable
                  as List<int>?,
        dayOfMonth: freezed == dayOfMonth
            ? _value.dayOfMonth
            : dayOfMonth // ignore: cast_nullable_to_non_nullable
                  as int?,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecurrencePatternImpl implements _RecurrencePattern {
  const _$RecurrencePatternImpl({
    required this.type,
    this.interval = 1,
    final List<int>? weekdays,
    this.dayOfMonth,
    this.endDate,
  }) : _weekdays = weekdays;

  factory _$RecurrencePatternImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecurrencePatternImplFromJson(json);

  /// 繰り返しタイプ
  @override
  final RecurrenceType type;

  /// 繰り返し間隔 (例: 2 = 2日ごと、2週間ごと)
  @override
  @JsonKey()
  final int interval;

  /// 週単位の繰り返しで使用する曜日リスト
  /// 1=月曜, 2=火曜, ..., 7=日曜
  /// 例: [1, 3, 5] = 月・水・金
  final List<int>? _weekdays;

  /// 週単位の繰り返しで使用する曜日リスト
  /// 1=月曜, 2=火曜, ..., 7=日曜
  /// 例: [1, 3, 5] = 月・水・金
  @override
  List<int>? get weekdays {
    final value = _weekdays;
    if (value == null) return null;
    if (_weekdays is EqualUnmodifiableListView) return _weekdays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// 月単位の繰り返しで使用する日
  /// 1-31 または null (日付がない月はスキップ)
  @override
  final int? dayOfMonth;

  /// 繰り返し終了日 (null = 無期限)
  @override
  final DateTime? endDate;

  @override
  String toString() {
    return 'RecurrencePattern(type: $type, interval: $interval, weekdays: $weekdays, dayOfMonth: $dayOfMonth, endDate: $endDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurrencePatternImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.interval, interval) ||
                other.interval == interval) &&
            const DeepCollectionEquality().equals(other._weekdays, _weekdays) &&
            (identical(other.dayOfMonth, dayOfMonth) ||
                other.dayOfMonth == dayOfMonth) &&
            (identical(other.endDate, endDate) || other.endDate == endDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    type,
    interval,
    const DeepCollectionEquality().hash(_weekdays),
    dayOfMonth,
    endDate,
  );

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurrencePatternImplCopyWith<_$RecurrencePatternImpl> get copyWith =>
      __$$RecurrencePatternImplCopyWithImpl<_$RecurrencePatternImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecurrencePatternImplToJson(this);
  }
}

abstract class _RecurrencePattern implements RecurrencePattern {
  const factory _RecurrencePattern({
    required final RecurrenceType type,
    final int interval,
    final List<int>? weekdays,
    final int? dayOfMonth,
    final DateTime? endDate,
  }) = _$RecurrencePatternImpl;

  factory _RecurrencePattern.fromJson(Map<String, dynamic> json) =
      _$RecurrencePatternImpl.fromJson;

  /// 繰り返しタイプ
  @override
  RecurrenceType get type;

  /// 繰り返し間隔 (例: 2 = 2日ごと、2週間ごと)
  @override
  int get interval;

  /// 週単位の繰り返しで使用する曜日リスト
  /// 1=月曜, 2=火曜, ..., 7=日曜
  /// 例: [1, 3, 5] = 月・水・金
  @override
  List<int>? get weekdays;

  /// 月単位の繰り返しで使用する日
  /// 1-31 または null (日付がない月はスキップ)
  @override
  int? get dayOfMonth;

  /// 繰り返し終了日 (null = 無期限)
  @override
  DateTime? get endDate;

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecurrencePatternImplCopyWith<_$RecurrencePatternImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
