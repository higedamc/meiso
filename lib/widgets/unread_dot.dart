import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The ambient / locating mark for unread comments (issue #219 §1, L4): a
/// plain dot, never a number. Counting belongs on the task tile.
///
/// Labelled for screen readers so it is read as a state, not skipped as
/// decoration. Callers build it only while there is something unread — the
/// absence of the widget is the "nothing here" state.
class UnreadDot extends StatelessWidget {
  const UnreadDot({required this.color, this.size = 7, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).unreadCommentsIndicatorLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
