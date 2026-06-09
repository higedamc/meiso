import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/core/config/app_config.dart';
import 'package:meiso/features/feature_gate/feature_id.dart';
import 'package:meiso/models/app_settings.dart';
import 'package:meiso/providers/app_settings_provider.dart';

class FeatureGateService {
  const FeatureGateService();

  bool get isBetaChannel => AppConfig.isBetaChannel;

  bool canShowExperimentalSettings() => isBetaChannel;

  bool channelAllowsFeature(FeatureId featureId) {
    switch (featureId) {
      case FeatureId.asanaMode:
      case FeatureId.wunderlistMode:
      case FeatureId.kanbanMode:
      case FeatureId.taskLinking:
        return isBetaChannel;
    }
  }

  bool isFeatureEnabled(AppSettings settings, FeatureId featureId) {
    if (!channelAllowsFeature(featureId)) {
      return false;
    }
    return settings.featureFlags[featureId.key] ?? false;
  }

  List<TaskUiMode> availableModes(AppSettings settings) {
    final modes = <TaskUiMode>[TaskUiMode.reminders];
    if (isFeatureEnabled(settings, FeatureId.asanaMode)) {
      modes.add(TaskUiMode.asana);
    }
    if (isFeatureEnabled(settings, FeatureId.wunderlistMode)) {
      modes.add(TaskUiMode.wunderlist);
    }
    if (isFeatureEnabled(settings, FeatureId.kanbanMode)) {
      modes.add(TaskUiMode.kanban);
    }
    return modes;
  }

  TaskUiMode resolveActiveMode(AppSettings settings) {
    final modes = availableModes(settings);
    return modes.contains(settings.taskUiMode)
        ? settings.taskUiMode
        : TaskUiMode.reminders;
  }

  bool canUseTaskLinking(AppSettings settings) {
    final activeMode = resolveActiveMode(settings);
    if (activeMode != TaskUiMode.asana) {
      return false;
    }
    return isFeatureEnabled(settings, FeatureId.taskLinking);
  }
}

final featureGateServiceProvider = Provider<FeatureGateService>((ref) {
  return const FeatureGateService();
});

final activeTaskUiModeProvider = Provider<TaskUiMode>((ref) {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  if (settings == null) {
    return TaskUiMode.reminders;
  }
  final gate = ref.watch(featureGateServiceProvider);
  return gate.resolveActiveMode(settings);
});
