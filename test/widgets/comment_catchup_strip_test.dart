import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/presentation/providers/comment_catchup_providers.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/presentation/comment_catchup/comment_catchup_screen.dart';
import 'package:meiso/widgets/comment_catchup_strip.dart';

/// Test double for the real [CommentCatchupArmedCountNotifier]: a fixed,
/// settable count with none of the arm/re-arm bookkeeping, since the widget
/// only needs to prove it renders whatever the provider currently holds.
class _FakeArmedCountNotifier extends CommentCatchupArmedCountNotifier {
  _FakeArmedCountNotifier([this._initial = 1]);

  final int? _initial;

  @override
  int? build() => _initial;

  void set(int? value) => state = value;
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      commentCatchupArmedCountProvider.overrideWith(
        _FakeArmedCountNotifier.new,
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

    testWidgets('re-renders when the armed count changes (e.g. on resume), '
        'not when it merely holds a new value at build time', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          commentCatchupArmedCountProvider.overrideWith(
            _FakeArmedCountNotifier.new,
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

      // Simulates a re-arm (e.g. app resume), the only event that is
      // supposed to move this provider's value once built.
      final notifier =
          container.read(commentCatchupArmedCountProvider.notifier)
              as _FakeArmedCountNotifier;
      notifier.set(5);
      await tester.pump();

      expect(find.textContaining('5 new comments'), findsOneWidget);
      expect(find.textContaining('1 new comments'), findsNothing);
    });

    testWidgets('tapping the close button dismisses without opening the list', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          commentCatchupArmedCountProvider.overrideWith(
            () => _FakeArmedCountNotifier(3),
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
