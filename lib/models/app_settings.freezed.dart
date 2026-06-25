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

  /// リレーリスト（NIP-65 kind 10002から同期）
  List<String> get relays => throw _privateConstructorUsedError;

  /// Tor接続モード
  TorMode get torMode => throw _privateConstructorUsedError;

  /// プロキシURL（Orbotモード使用時、通常は socks5://127.0.0.1:9050）
  String get proxyUrl => throw _privateConstructorUsedError;

  /// カスタムリストの順番（リストIDの配列）
  List<String> get customListOrder => throw _privateConstructorUsedError;

  /// 承諾済み共有グループの ID 集合（端末間で承諾状態を同期するため）。
  /// 招待イベント(kind 30078)はリレー上に残るため、これを同期しないと新端末で
  /// 再び「招待中」表示になる。group_nsec 等の秘密はリレーに出さず groupId のみ保持。
  List<String> get joinedGroupIds => throw _privateConstructorUsedError;

  /// 最後に見ていたカスタムリストID
  String? get lastViewedCustomListId => throw _privateConstructorUsedError;

  /// タスクUIモード（既定: Reminders）
  TaskUiMode get taskUiMode => throw _privateConstructorUsedError;

  /// 実験機能フラグ（feature_id -> enabled）
  Map<String, bool> get featureFlags => throw _privateConstructorUsedError;

  /// 完了済みタスクを非表示にする
  bool get hideCompletedTasks => throw _privateConstructorUsedError;

  /// NIP-89 `client` タグをイベントに付与する（false = オプトアウト）
  bool get nip89ClientTagEnabled => throw _privateConstructorUsedError;

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
    List<String> relays,
    TorMode torMode,
    String proxyUrl,
    List<String> customListOrder,
    List<String> joinedGroupIds,
    String? lastViewedCustomListId,
    TaskUiMode taskUiMode,
    Map<String, bool> featureFlags,
    bool hideCompletedTasks,
    bool nip89ClientTagEnabled,
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
    Object? torMode = null,
    Object? proxyUrl = null,
    Object? customListOrder = null,
    Object? joinedGroupIds = null,
    Object? lastViewedCustomListId = freezed,
    Object? taskUiMode = null,
    Object? featureFlags = null,
    Object? hideCompletedTasks = null,
    Object? nip89ClientTagEnabled = null,
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
            torMode: null == torMode
                ? _value.torMode
                : torMode // ignore: cast_nullable_to_non_nullable
                      as TorMode,
            proxyUrl: null == proxyUrl
                ? _value.proxyUrl
                : proxyUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            customListOrder: null == customListOrder
                ? _value.customListOrder
                : customListOrder // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            joinedGroupIds: null == joinedGroupIds
                ? _value.joinedGroupIds
                : joinedGroupIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            lastViewedCustomListId: freezed == lastViewedCustomListId
                ? _value.lastViewedCustomListId
                : lastViewedCustomListId // ignore: cast_nullable_to_non_nullable
                      as String?,
            taskUiMode: null == taskUiMode
                ? _value.taskUiMode
                : taskUiMode // ignore: cast_nullable_to_non_nullable
                      as TaskUiMode,
            featureFlags: null == featureFlags
                ? _value.featureFlags
                : featureFlags // ignore: cast_nullable_to_non_nullable
                      as Map<String, bool>,
            hideCompletedTasks: null == hideCompletedTasks
                ? _value.hideCompletedTasks
                : hideCompletedTasks // ignore: cast_nullable_to_non_nullable
                      as bool,
            nip89ClientTagEnabled: null == nip89ClientTagEnabled
                ? _value.nip89ClientTagEnabled
                : nip89ClientTagEnabled // ignore: cast_nullable_to_non_nullable
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
    List<String> relays,
    TorMode torMode,
    String proxyUrl,
    List<String> customListOrder,
    List<String> joinedGroupIds,
    String? lastViewedCustomListId,
    TaskUiMode taskUiMode,
    Map<String, bool> featureFlags,
    bool hideCompletedTasks,
    bool nip89ClientTagEnabled,
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
    Object? torMode = null,
    Object? proxyUrl = null,
    Object? customListOrder = null,
    Object? joinedGroupIds = null,
    Object? lastViewedCustomListId = freezed,
    Object? taskUiMode = null,
    Object? featureFlags = null,
    Object? hideCompletedTasks = null,
    Object? nip89ClientTagEnabled = null,
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
            ? _value.relays
            : relays // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        torMode: null == torMode
            ? _value.torMode
            : torMode // ignore: cast_nullable_to_non_nullable
                  as TorMode,
        proxyUrl: null == proxyUrl
            ? _value.proxyUrl
            : proxyUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        customListOrder: null == customListOrder
            ? _value.customListOrder
            : customListOrder // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        joinedGroupIds: null == joinedGroupIds
            ? _value.joinedGroupIds
            : joinedGroupIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        lastViewedCustomListId: freezed == lastViewedCustomListId
            ? _value.lastViewedCustomListId
            : lastViewedCustomListId // ignore: cast_nullable_to_non_nullable
                  as String?,
        taskUiMode: null == taskUiMode
            ? _value.taskUiMode
            : taskUiMode // ignore: cast_nullable_to_non_nullable
                  as TaskUiMode,
        featureFlags: null == featureFlags
            ? _value.featureFlags
            : featureFlags // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        hideCompletedTasks: null == hideCompletedTasks
            ? _value.hideCompletedTasks
            : hideCompletedTasks // ignore: cast_nullable_to_non_nullable
                  as bool,
        nip89ClientTagEnabled: null == nip89ClientTagEnabled
            ? _value.nip89ClientTagEnabled
            : nip89ClientTagEnabled // ignore: cast_nullable_to_non_nullable
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
    this.relays = const [],
    this.torMode = TorMode.disabled,
    this.proxyUrl = 'socks5://127.0.0.1:9050',
    this.customListOrder = const [],
    this.joinedGroupIds = const [],
    this.lastViewedCustomListId,
    this.taskUiMode = TaskUiMode.reminders,
    this.featureFlags = const <String, bool>{},
    this.hideCompletedTasks = false,
    this.nip89ClientTagEnabled = true,
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

  /// リレーリスト（NIP-65 kind 10002から同期）
  @override
  @JsonKey()
  final List<String> relays;

  /// Tor接続モード
  @override
  @JsonKey()
  final TorMode torMode;

  /// プロキシURL（Orbotモード使用時、通常は socks5://127.0.0.1:9050）
  @override
  @JsonKey()
  final String proxyUrl;

  /// カスタムリストの順番（リストIDの配列）
  @override
  @JsonKey()
  final List<String> customListOrder;

  /// 承諾済み共有グループの ID 集合（端末間で承諾状態を同期するため）。
  /// 招待イベント(kind 30078)はリレー上に残るため、これを同期しないと新端末で
  /// 再び「招待中」表示になる。group_nsec 等の秘密はリレーに出さず groupId のみ保持。
  @override
  @JsonKey()
  final List<String> joinedGroupIds;

  /// 最後に見ていたカスタムリストID
  @override
  final String? lastViewedCustomListId;

  /// タスクUIモード（既定: Reminders）
  @override
  @JsonKey()
  final TaskUiMode taskUiMode;

  /// 実験機能フラグ（feature_id -> enabled）
  @override
  @JsonKey()
  final Map<String, bool> featureFlags;

  /// 完了済みタスクを非表示にする
  @override
  @JsonKey()
  final bool hideCompletedTasks;

  /// NIP-89 `client` タグをイベントに付与する（false = オプトアウト）
  @override
  @JsonKey()
  final bool nip89ClientTagEnabled;

  /// 最終更新日時
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'AppSettings(darkMode: $darkMode, weekStartDay: $weekStartDay, calendarView: $calendarView, notificationsEnabled: $notificationsEnabled, relays: $relays, torMode: $torMode, proxyUrl: $proxyUrl, customListOrder: $customListOrder, joinedGroupIds: $joinedGroupIds, lastViewedCustomListId: $lastViewedCustomListId, taskUiMode: $taskUiMode, featureFlags: $featureFlags, hideCompletedTasks: $hideCompletedTasks, nip89ClientTagEnabled: $nip89ClientTagEnabled, updatedAt: $updatedAt)';
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
            const DeepCollectionEquality().equals(other.relays, relays) &&
            (identical(other.torMode, torMode) || other.torMode == torMode) &&
            (identical(other.proxyUrl, proxyUrl) ||
                other.proxyUrl == proxyUrl) &&
            const DeepCollectionEquality().equals(
              other.customListOrder,
              customListOrder,
            ) &&
            const DeepCollectionEquality().equals(
              other.joinedGroupIds,
              joinedGroupIds,
            ) &&
            (identical(other.lastViewedCustomListId, lastViewedCustomListId) ||
                other.lastViewedCustomListId == lastViewedCustomListId) &&
            (identical(other.taskUiMode, taskUiMode) ||
                other.taskUiMode == taskUiMode) &&
            const DeepCollectionEquality().equals(
              other.featureFlags,
              featureFlags,
            ) &&
            (identical(other.hideCompletedTasks, hideCompletedTasks) ||
                other.hideCompletedTasks == hideCompletedTasks) &&
            (identical(other.nip89ClientTagEnabled, nip89ClientTagEnabled) ||
                other.nip89ClientTagEnabled == nip89ClientTagEnabled) &&
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
    const DeepCollectionEquality().hash(relays),
    torMode,
    proxyUrl,
    const DeepCollectionEquality().hash(customListOrder),
    const DeepCollectionEquality().hash(joinedGroupIds),
    lastViewedCustomListId,
    taskUiMode,
    const DeepCollectionEquality().hash(featureFlags),
    hideCompletedTasks,
    nip89ClientTagEnabled,
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
    final List<String> relays,
    final TorMode torMode,
    final String proxyUrl,
    final List<String> customListOrder,
    final List<String> joinedGroupIds,
    final String? lastViewedCustomListId,
    final TaskUiMode taskUiMode,
    final Map<String, bool> featureFlags,
    final bool hideCompletedTasks,
    final bool nip89ClientTagEnabled,
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

  /// リレーリスト（NIP-65 kind 10002から同期）
  @override
  List<String> get relays;

  /// Tor接続モード
  @override
  TorMode get torMode;

  /// プロキシURL（Orbotモード使用時、通常は socks5://127.0.0.1:9050）
  @override
  String get proxyUrl;

  /// カスタムリストの順番（リストIDの配列）
  @override
  List<String> get customListOrder;

  /// 承諾済み共有グループの ID 集合（端末間で承諾状態を同期するため）。
  /// 招待イベント(kind 30078)はリレー上に残るため、これを同期しないと新端末で
  /// 再び「招待中」表示になる。group_nsec 等の秘密はリレーに出さず groupId のみ保持。
  @override
  List<String> get joinedGroupIds;

  /// 最後に見ていたカスタムリストID
  @override
  String? get lastViewedCustomListId;

  /// タスクUIモード（既定: Reminders）
  @override
  TaskUiMode get taskUiMode;

  /// 実験機能フラグ（feature_id -> enabled）
  @override
  Map<String, bool> get featureFlags;

  /// 完了済みタスクを非表示にする
  @override
  bool get hideCompletedTasks;

  /// NIP-89 `client` タグをイベントに付与する（false = オプトアウト）
  @override
  bool get nip89ClientTagEnabled;

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
