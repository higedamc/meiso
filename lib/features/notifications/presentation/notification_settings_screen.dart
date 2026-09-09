import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';

import '../../../app_theme.dart';
import '../domain/notification_settings.dart';
import 'notification_settings_provider.dart';

/// Notification settings (Phase 3, Leaf 3).
///
/// Persists only the two user-facing keys from `NotificationPrefsKeys`.
/// Starting or stopping the resident service in response to these values is
/// Phase 4 (integration) work and is deliberately not done here.
///
/// Besides the two switches the screen states, in plain words, the two
/// behaviours a user will otherwise discover by surprise:
/// 1. `flutter_foreground_task` restores its Dart callback from
///    SharedPreferences, so after a device restart nothing is delivered until
///    the app has been opened once.
/// 2. Comments on personal tasks are not notified in Phase 3.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user may flip the exemption in system settings and come back, so the
  /// cached status is re-read whenever the app returns to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(batteryOptimizationExemptProvider);
    }
  }

  Future<void> _requestBatteryExemption() async {
    final gate = ref.read(batteryOptimizationGateProvider);
    try {
      await gate.request();
    } on Exception {
      // The dialog result is not needed: the status provider is re-read
      // below and shows whatever the system now reports.
    }
    if (mounted) {
      ref.invalidate(batteryOptimizationExemptProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final settings = settingsAsync.valueOrNull;

    final Widget body;
    if (settings != null) {
      body = _SettingsBody(
        settings: settings,
        saveFailed: settingsAsync.hasError,
        onRequestBatteryExemption: _requestBatteryExemption,
      );
    } else if (settingsAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.notificationSettingsLoadError),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(notificationSettingsProvider),
              child: Text(l10n.retryButton),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: body,
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({
    required this.settings,
    required this.saveFailed,
    required this.onRequestBatteryExemption,
  });

  final NotificationSettings settings;
  final bool saveFailed;
  final Future<void> Function() onRequestBatteryExemption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final exemptAsync = ref.watch(batteryOptimizationExemptProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (saveFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              l10n.notificationSettingsSaveError,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        _SectionHeader(l10n.notificationsSectionHeader),
        _SectionCard(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('notifications_master_switch'),
                title: Text(l10n.notificationsMasterTitle),
                subtitle: Text(
                  l10n.notificationsMasterSubtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.enabled,
                onChanged: (value) => controller.setEnabled(enabled: value),
              ),
              const _InsetDivider(),
              SwitchListTile(
                key: const Key('notifications_shared_comments_switch'),
                title: Text(l10n.notificationsSharedCommentsTitle),
                subtitle: Text(
                  l10n.notificationsSharedCommentsSubtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.sharedTaskComments,
                // Greyed out while the master switch is off: the value is
                // kept, but nothing is delivered without the master switch.
                onChanged: settings.enabled
                    ? (value) =>
                        controller.setSharedTaskComments(enabled: value)
                    : null,
              ),
            ],
          ),
        ),
        _SectionHeader(l10n.notificationsBatteryHeader),
        _SectionCard(
          child: ListTile(
            key: const Key('battery_optimization_tile'),
            leading: const Icon(
              Icons.battery_saver,
              color: AppTheme.primaryPurple,
            ),
            title: Text(l10n.batteryOptimizationTitle),
            subtitle: Text(
              exemptAsync.when(
                data: (exempt) => exempt
                    ? l10n.batteryOptimizationExempt
                    : l10n.batteryOptimizationRestricted,
                loading: () => l10n.batteryOptimizationChecking,
                error: (_, _) => l10n.batteryOptimizationUnavailable,
              ),
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: exemptAsync.valueOrNull == false
                ? TextButton(
                    key: const Key('battery_optimization_allow'),
                    onPressed: onRequestBatteryExemption,
                    child: Text(l10n.batteryOptimizationAllow),
                  )
                : null,
          ),
        ),
        _SectionHeader(l10n.notificationsNotesHeader),
        _SectionCard(
          child: Column(
            children: [
              _NoteTile(
                icon: Icons.restart_alt,
                title: l10n.notificationsRestartCaveatTitle,
                body: l10n.notificationsRestartCaveatBody,
              ),
              const _InsetDivider(),
              _NoteTile(
                icon: Icons.person_outline,
                title: l10n.notificationsPersonalTasksTitle,
                body: l10n.notificationsPersonalTasksBody,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section header, same look as the Settings screen.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Text(text.toUpperCase(), style: AppTheme.sectionHeader(context)),
    );
  }
}

/// Section card, same look as the Settings screen.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.sectionCardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
    );
  }
}

/// Read-only explanatory row.
class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryPurple),
      title: Text(title),
      subtitle: Text(body, style: const TextStyle(fontSize: 12)),
      isThreeLine: true,
    );
  }
}
