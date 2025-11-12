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

  /// リレーリスト（NIP-65 kind 10002から同期）
  List<String> get relays => throw _privateConstructorUsedError;

  /// Tor有効/無効（Orbot経由での接続）
  bool get torEnabled => throw _privateConstructorUsedError;

  /// プロキシURL（通常は socks5://127.0.0.1:9050）
  String get proxyUrl => throw _privateConstructorUsedError;

  /// カスタムリストの順番（リストIDの配列）
  List<String> get customListOrder => throw _privateConstructorUsedError;

  /// 最後に見ていたカスタムリストID
  String? get lastViewedCustomListId => throw _privateConstructorUsedError;

  /// 最終更新日時
  DateTime get updatedAt => throw _privateConstructorUsedError;

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
    List<String> relays,
    bool torEnabled,
    String proxyUrl,
    List<String> customListOrder,
    String? lastViewedCustomListId,
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
    Object? relays = null,
    Object? torEnabled = null,
    Object? proxyUrl = null,
    Object? customListOrder = null,
    Object? lastViewedCustomListId = freezed,
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
            relays: null == relays
                ? _value.relays
                : relays // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            torEnabled: null == torEnabled
                ? _value.torEnabled
                : torEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            proxyUrl: null == proxyUrl
                ? _value.proxyUrl
                : proxyUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            customListOrder: null == customListOrder
                ? _value.customListOrder
                : customListOrder // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            lastViewedCustomListId: freezed == lastViewedCustomListId
                ? _value.lastViewedCustomListId
                : lastViewedCustomListId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
    List<String> relays,
    bool torEnabled,
    String proxyUrl,
    List<String> customListOrder,
    String? lastViewedCustomListId,
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
    Object? relays = null,
    Object? torEnabled = null,
    Object? proxyUrl = null,
    Object? customListOrder = null,
    Object? lastViewedCustomListId = freezed,
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
        relays: null == relays
            ? _value._relays
            : relays // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        torEnabled: null == torEnabled
            ? _value.torEnabled
            : torEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        proxyUrl: null == proxyUrl
            ? _value.proxyUrl
            : proxyUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        customListOrder: null == customListOrder
            ? _value._customListOrder
            : customListOrder // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        lastViewedCustomListId: freezed == lastViewedCustomListId
            ? _value.lastViewedCustomListId
            : lastViewedCustomListId // ignore: cast_nullable_to_non_nullable
                  as String?,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$AppSettingsImpl extends _AppSettings {
  const _$AppSettingsImpl({
    required this.darkMode,
    required this.weekStartDay,
    required this.calendarView,
    required this.notificationsEnabled,
    required final List<String> relays,
    required this.torEnabled,
    required this.proxyUrl,
    required final List<String> customListOrder,
    this.lastViewedCustomListId,
    required this.updatedAt,
  }) : _relays = relays,
       _customListOrder = customListOrder,
       super._();

  /// ダークモード設定
  @override
  final bool darkMode;

  /// 週の開始曜日 (0=日曜, 1=月曜, ...)
  @override
  final int weekStartDay;

  /// カレンダー表示形式 ("week" | "month")
  @override
  final String calendarView;

  /// 通知設定
  @override
  final bool notificationsEnabled;

  /// リレーリスト（NIP-65 kind 10002から同期）
  final List<String> _relays;

  /// リレーリスト（NIP-65 kind 10002から同期）
  @override
  List<String> get relays {
    if (_relays is EqualUnmodifiableListView) return _relays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relays);
  }

  /// Tor有効/無効（Orbot経由での接続）
  @override
  final bool torEnabled;

  /// プロキシURL（通常は socks5://127.0.0.1:9050）
  @override
  final String proxyUrl;

  /// カスタムリストの順番（リストIDの配列）
  final List<String> _customListOrder;

  /// カスタムリストの順番（リストIDの配列）
  @override
  List<String> get customListOrder {
    if (_customListOrder is EqualUnmodifiableListView) return _customListOrder;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customListOrder);
  }

  /// 最後に見ていたカスタムリストID
  @override
  final String? lastViewedCustomListId;

  /// 最終更新日時
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'AppSettings(darkMode: $darkMode, weekStartDay: $weekStartDay, calendarView: $calendarView, notificationsEnabled: $notificationsEnabled, relays: $relays, torEnabled: $torEnabled, proxyUrl: $proxyUrl, customListOrder: $customListOrder, lastViewedCustomListId: $lastViewedCustomListId, updatedAt: $updatedAt)';
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
            const DeepCollectionEquality().equals(other._relays, _relays) &&
            (identical(other.torEnabled, torEnabled) ||
                other.torEnabled == torEnabled) &&
            (identical(other.proxyUrl, proxyUrl) ||
                other.proxyUrl == proxyUrl) &&
            const DeepCollectionEquality().equals(
              other._customListOrder,
              _customListOrder,
            ) &&
            (identical(other.lastViewedCustomListId, lastViewedCustomListId) ||
                other.lastViewedCustomListId == lastViewedCustomListId) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    darkMode,
    weekStartDay,
    calendarView,
    notificationsEnabled,
    const DeepCollectionEquality().hash(_relays),
    torEnabled,
    proxyUrl,
    const DeepCollectionEquality().hash(_customListOrder),
    lastViewedCustomListId,
    updatedAt,
  );

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      __$$AppSettingsImplCopyWithImpl<_$AppSettingsImpl>(this, _$identity);
}

abstract class _AppSettings extends AppSettings {
  const factory _AppSettings({
    required final bool darkMode,
    required final int weekStartDay,
    required final String calendarView,
    required final bool notificationsEnabled,
    required final List<String> relays,
    required final bool torEnabled,
    required final String proxyUrl,
    required final List<String> customListOrder,
    final String? lastViewedCustomListId,
    required final DateTime updatedAt,
  }) = _$AppSettingsImpl;
  const _AppSettings._() : super._();

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

  /// リレーリスト（NIP-65 kind 10002から同期）
  @override
  List<String> get relays;

  /// Tor有効/無効（Orbot経由での接続）
  @override
  bool get torEnabled;

  /// プロキシURL（通常は socks5://127.0.0.1:9050）
  @override
  String get proxyUrl;

  /// カスタムリストの順番（リストIDの配列）
  @override
  List<String> get customListOrder;

  /// 最後に見ていたカスタムリストID
  @override
  String? get lastViewedCustomListId;

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
