import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/presentation/providers/comment_catchup_providers.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/presentation/comment_catchup/comment_catchup_screen.dart';
import 'package:meiso/widgets/comment_catchup_strip.dart';

/// Lets a test change the strip's count after the first pump, to prove the
/// widget watches the provider in `build` rather than snapshotting it once
/// (the same cold-start-value-arrives-later bug this lane keeps hitting).
final _testCount = StateProvider<int>((ref) => 1);

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      totalUnreadCommentCountProvider.overrideWith(
        (ref) => ref.watch(_testCount),
      ),
      commentCatchupEntriesProvider.overrideWithValue(const []),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('CommentCatchupStrip', () {
    testWidgets('shows the unread count in its message', (tester) async {
      await tester.pumpWidget(_wrap(const CommentCatchupStrip()));

      expect(find.textContaining('1 new comments'), findsOneWidget);
    });

    testWidgets('updates when the unread count changes after the first build', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          totalUnreadCommentCountProvider.overrideWith(
            (ref) => ref.watch(_testCount),
          ),
          commentCatchupEntriesProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentCatchupStrip()),
          ),
        ),
      );
      expect(find.textContaining('1 new comments'), findsOneWidget);

      container.read(_testCount.notifier).state = 5;
      await tester.pump();

      expect(find.textContaining('5 new comments'), findsOneWidget);
      expect(find.textContaining('1 new comments'), findsNothing);
    });

    testWidgets('tapping the close button dismisses without opening the list', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          totalUnreadCommentCountProvider.overrideWithValue(3),
          commentCatchupEntriesProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentCatchupStrip()),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(container.read(commentCatchupDismissedProvider), isTrue);
      expect(find.byType(CommentCatchupScreen), findsNothing);
    });

    testWidgets('tapping the body opens the catch-up list', (tester) async {
      await tester.pumpWidget(_wrap(const CommentCatchupStrip()));

      await tester.tap(find.textContaining('new comments'));
      await tester.pumpAndSettle();

      expect(find.byType(CommentCatchupScreen), findsOneWidget);
    });
  });
}
