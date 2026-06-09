import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/widgets/expandable_calendar.dart';
import 'package:table_calendar/table_calendar.dart';

/// Regression guard for the reported crash:
///   LateInitializationError: Field '_pageController@...' has already been initialized.
///
/// Root cause: table_calendar keeps its `_pageController` as a `late final` that is
/// assigned via the `onCalendarCreated` callback fired from the inner
/// `TableCalendarBase.initState`. Keeping the calendar permanently mounted (the old
/// AnimatedAlign(heightFactor) approach) lets the outer state outlive the whole
/// session, so any re-inflation of the inner subtree re-runs the assignment and
/// crashes. ExpandableCalendar now mounts the calendar only while visible (plus the
/// closing animation), guaranteeing a fresh state on every open.

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            ExpandableCalendar(
              isVisible: _visible,
              onDaySelected: (_) => setState(() => _visible = false),
            ),
            TextButton(
              key: const Key('toggle'),
              onPressed: () => setState(() => _visible = !_visible),
              child: const Text('toggle'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('calendar is not mounted while hidden', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar<void>), findsNothing);
  });

  testWidgets('calendar mounts on open and unmounts after close', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle'))); // open
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar<void>), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle'))); // close
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar<void>), findsNothing);
  });

  testWidgets('repeated open/close cycles never throw', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('toggle'))); // open
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle'))); // close
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid toggle during animation never throws', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('toggle')));
      await tester.pump(const Duration(milliseconds: 80)); // mid animation
      await tester.tap(find.byKey(const Key('toggle')));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
