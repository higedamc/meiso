import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/widgets/comment_intro_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('CommentIntroCard', () {
    testWidgets('shows the body text', (tester) async {
      await tester.pumpWidget(_wrap(CommentIntroCard(onDismiss: () {})));

      expect(
        find.textContaining('Tasks can now have comments'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the card body calls onDismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(CommentIntroCard(onDismiss: () => dismissed = true)),
      );

      await tester.tap(find.byType(CommentIntroCard));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('tapping the ✕ button calls onDismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(CommentIntroCard(onDismiss: () => dismissed = true)),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });
}
