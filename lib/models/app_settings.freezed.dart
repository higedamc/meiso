// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) {
  return _AppSettings.fromJson(json);
}

/// @nodoc
mixin _$AppSettings {
  /// ダークモード設定
  bool get darkMode => throw _privateConstructorUsedError;

  /// 週の開始曜日 (0=日曜, 1=月曜, ...)
  int get weekStartDay => throw _privateConstructorUsedError;

  /// カレンダー表示形式 ("week" | "month")
  String get calendarView => throw _privateConstructorUsedError;

  /// 通知設定
  bool get notificationsEnabled => throw _privateConstructorUsedError;

  /// 最終更新日時
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsCopyWith<AppSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsCopyWith<$Res> {
  factory $AppSettingsCopyWith(
    AppSettings value,
    $Res Function(AppSettings) then,
  ) = _$AppSettingsCopyWithImpl<$Res, AppSettings>;
  @useResult
  $Res call({
    bool darkMode,
    int weekStartDay,
    String calendarView,
    bool notificationsEnabled,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$AppSettingsCopyWithImpl<$Res, $Val extends AppSettings>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? darkMode = null,
    Object? weekStartDay = null,
    Object? calendarView = null,
    Object? notificationsEnabled = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            darkMode: null == darkMode
                ? _value.darkMode
                : darkMode // ignore: cast_nullable_to_non_nullable
                      as bool,
            weekStartDay: null == weekStartDay
                ? _value.weekStartDay
                : weekStartDay // ignore: cast_nullable_to_non_nullable
                      as int,
            calendarView: null == calendarView
                ? _value.calendarView
                : calendarView // ignore: cast_nullable_to_non_nullable
                      as String,
            notificationsEnabled: null == notificationsEnabled
                ? _value.notificationsEnabled
                : notificationsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$AppSettingsImplCopyWith<$Res>
    implements $AppSettingsCopyWith<$Res> {
  factory _$$AppSettingsImplCopyWith(
    _$AppSettingsImpl value,
    $Res Function(_$AppSettingsImpl) then,
  ) = __$$AppSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool darkMode,
    int weekStartDay,
    String calendarView,
    bool notificationsEnabled,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$AppSettingsImplCopyWithImpl<$Res>
    extends _$AppSettingsCopyWithImpl<$Res, _$AppSettingsImpl>
    implements _$$AppSettingsImplCopyWith<$Res> {
  __$$AppSettingsImplCopyWithImpl(
    _$AppSettingsImpl _value,
    $Res Function(_$AppSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? darkMode = null,
    Object? weekStartDay = null,
    Object? calendarView = null,
    Object? notificationsEnabled = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$AppSettingsImpl(
        darkMode: null == darkMode
            ? _value.darkMode
            : darkMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        weekStartDay: null == weekStartDay
            ? _value.weekStartDay
            : weekStartDay // ignore: cast_nullable_to_non_nullable
                  as int,
        calendarView: null == calendarView
            ? _value.calendarView
            : calendarView // ignore: cast_nullable_to_non_nullable
                  as String,
        notificationsEnabled: null == notificationsEnabled
            ? _value.notificationsEnabled
            : notificationsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$AppSettingsImpl implements _AppSettings {
  const _$AppSettingsImpl({
    this.darkMode = false,
    this.weekStartDay = 1,
    this.calendarView = 'week',
    this.notificationsEnabled = true,
    required this.updatedAt,
  });

  factory _$AppSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppSettingsImplFromJson(json);

  /// ダークモード設定
  @override
  @JsonKey()
  final bool darkMode;

  /// 週の開始曜日 (0=日曜, 1=月曜, ...)
  @override
  @JsonKey()
  final int weekStartDay;

  /// カレンダー表示形式 ("week" | "month")
  @override
  @JsonKey()
  final String calendarView;

  /// 通知設定
  @override
  @JsonKey()
  final bool notificationsEnabled;

  /// 最終更新日時
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'AppSettings(darkMode: $darkMode, weekStartDay: $weekStartDay, calendarView: $calendarView, notificationsEnabled: $notificationsEnabled, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsImpl &&
            (identical(other.darkMode, darkMode) ||
                other.darkMode == darkMode) &&
            (identical(other.weekStartDay, weekStartDay) ||
                other.weekStartDay == weekStartDay) &&
            (identical(other.calendarView, calendarView) ||
                other.calendarView == calendarView) &&
            (identical(other.notificationsEnabled, notificationsEnabled) ||
                other.notificationsEnabled == notificationsEnabled) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    darkMode,
    weekStartDay,
    calendarView,
    notificationsEnabled,
    updatedAt,
  );

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      __$$AppSettingsImplCopyWithImpl<_$AppSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppSettingsImplToJson(this);
  }
}

abstract class _AppSettings implements AppSettings {
  const factory _AppSettings({
    final bool darkMode,
    final int weekStartDay,
    final String calendarView,
    final bool notificationsEnabled,
    required final DateTime updatedAt,
  }) = _$AppSettingsImpl;

  factory _AppSettings.fromJson(Map<String, dynamic> json) =
      _$AppSettingsImpl.fromJson;

  /// ダークモード設定
  @override
  bool get darkMode;

  /// 週の開始曜日 (0=日曜, 1=月曜, ...)
  @override
  int get weekStartDay;

  /// カレンダー表示形式 ("week" | "month")
  @override
  String get calendarView;

  /// 通知設定
  @override
  bool get notificationsEnabled;

  /// 最終更新日時
  @override
  DateTime get updatedAt;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
