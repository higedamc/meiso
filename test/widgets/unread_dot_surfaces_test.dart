import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/widgets/bottom_navigation.dart';
import 'package:meiso/widgets/date_tab_bar.dart';
import 'package:meiso/widgets/unread_dot.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void _noop() {}

Widget _bar({
  bool todayHasUnread = false,
  bool somedayHasUnread = false,
  bool merged = false,
}) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: BottomNavigation(
      onTodayTap: _noop,
      onAddTap: _noop,
      onSomedayTap: _noop,
      onSettingsTap: _noop,
      isSomedayActive: merged,
      somedayMerged: merged,
      mergedLabel: merged ? 'Groceries' : null,
      todayHasUnread: todayHasUnread,
      somedayHasUnread: somedayHasUnread,
    ),
  );
}

final List<DateTime> _week = List.generate(7, (i) => DateTime(2026, 1, 5 + i));

void main() {
  group('BottomNavigation ambient dots', () {
    testWidgets('no dots by default', (tester) async {
      await tester.pumpWidget(_app(_bar()));
      await tester.pumpAndSettle();
      expect(find.byType(UnreadDot), findsNothing);
    });

    testWidgets('one dot per lit segment, labelled, no number', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_bar(todayHasUnread: true, somedayHasUnread: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnreadDot), findsNWidgets(2));
      // The segment's InkWell merges its descendants, so a screen reader
      // hears the dot as part of the segment ("TODAY Unread comments").
      final semantics = tester.ensureSemantics();
      // Both dots are the same const instance, so address them by index.
      for (var i = 0; i < 2; i++) {
        expect(
          tester.getSemantics(find.byType(UnreadDot).at(i)).label,
          contains('Unread comments'),
        );
      }
      semantics.dispose();
      expect(find.textContaining(RegExp(r'^\d+$')), findsNothing);
    });

    testWidgets('TODAY only lights the TODAY segment', (tester) async {
      await tester.pumpWidget(_app(_bar(todayHasUnread: true)));
      await tester.pumpAndSettle();

      expect(find.byType(UnreadDot), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(UnreadDot),
          matching: find.widgetWithText(InkWell, 'TODAY'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('merged (list detail open): the one visible segment answers '
        '"anything, anywhere", so TODAY unread shows there too', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_bar(merged: true, todayHasUnread: true)));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.byType(UnreadDot),
          matching: find.widgetWithText(InkWell, 'Groceries'),
        ),
        findsOneWidget,
      );
    });
  });

  group('DateTabBar locating dots', () {
    testWidgets('no dots by default', (tester) async {
      await tester.pumpWidget(
        _app(DateTabBar(dates: _week, currentIndex: 2, onDateTap: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UnreadDot), findsNothing);
    });

    testWidgets('a dot on exactly the tabs whose day has unread, matched on '
        'the day regardless of the time of day', (tester) async {
      await tester.pumpWidget(
        _app(
          DateTabBar(
            dates: _week,
            currentIndex: 2,
            onDateTap: (_) {},
            datesWithUnread: {DateTime(2026, 1, 6), DateTime(2026, 1, 9)},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnreadDot), findsNWidgets(2));
      expect(
        find.ancestor(
          of: find.byType(UnreadDot),
          matching: find.widgetWithText(InkWell, '1/6'),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(UnreadDot),
          matching: find.widgetWithText(InkWell, '1/9'),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(UnreadDot),
          matching: find.widgetWithText(InkWell, '1/7'),
        ),
        findsNothing,
      );
    });
  });
}
