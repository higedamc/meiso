import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/app_settings.dart';

part 'app_settings_state.freezed.dart';

/// AppSettingsの状態を表すクラス
@freezed
class AppSettingsState with _$AppSettingsState {
  /// 初期状態
  const factory AppSettingsState.initial() = _Initial;
  
  /// 読み込み中
  const factory AppSettingsState.loading() = _Loading;
  
  /// 読み込み完了
  const factory AppSettingsState.loaded({
    required AppSettings settings,
  }) = _Loaded;
  
  /// エラー
  const factory AppSettingsState.error(Failure failure) = _Error;
}

