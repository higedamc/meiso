enum FeatureId {
  asanaMode,
  wunderlistMode,
  kanbanMode,
  taskLinking,
}

extension FeatureIdExtension on FeatureId {
  String get key {
    switch (this) {
      case FeatureId.asanaMode:
        return 'mode_asana';
      case FeatureId.wunderlistMode:
        return 'mode_wunderlist';
      case FeatureId.kanbanMode:
        return 'mode_kanban';
      case FeatureId.taskLinking:
        return 'task_linking';
    }
  }
}
