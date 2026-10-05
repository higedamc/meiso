import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/utils/todo_list_shrink_guard.dart';

void main() {
  group('isSuspiciousListShrink', () {
    test('lists below the minimum known count are never suspicious', () {
      expect(isSuspiciousListShrink(known: 0, next: 0), isFalse);
      expect(isSuspiciousListShrink(known: 1, next: 0), isFalse);
      expect(isSuspiciousListShrink(known: 2, next: 0), isFalse);
    });

    test('growing or equal counts are never suspicious', () {
      expect(isSuspiciousListShrink(known: 10, next: 10), isFalse);
      expect(isSuspiciousListShrink(known: 10, next: 11), isFalse);
    });

    test('refuses below half, allows at half (ceil boundary)', () {
      // known 10: ceil(5.0) = 5 -> 5 allowed, 4 refused
      expect(isSuspiciousListShrink(known: 10, next: 5), isFalse);
      expect(isSuspiciousListShrink(known: 10, next: 4), isTrue);
      // known 9: ceil(4.5) = 5 -> 5 allowed, 4 refused
      expect(isSuspiciousListShrink(known: 9, next: 5), isFalse);
      expect(isSuspiciousListShrink(known: 9, next: 4), isTrue);
      // known 3: ceil(1.5) = 2 -> 2 allowed, 1 refused
      expect(isSuspiciousListShrink(known: 3, next: 2), isFalse);
      expect(isSuspiciousListShrink(known: 3, next: 1), isTrue);
    });

    test('an empty publish of a known list is refused', () {
      expect(isSuspiciousListShrink(known: 3, next: 0), isTrue);
      expect(isSuspiciousListShrink(known: 200, next: 0), isTrue);
    });
  });

  group('findSuspiciousListShrinks', () {
    test('lists without a known count are skipped', () {
      final hits = findSuspiciousListShrinks(
        knownCounts: const {'default': 20},
        publishCounts: const {'default': 20, 'new-list': 0},
      );
      expect(hits, isEmpty);
    });

    test('reports every shrinking list with both counts', () {
      final hits = findSuspiciousListShrinks(
        knownCounts: const {'default': 20, 'work': 8, 'home': 4},
        publishCounts: const {'default': 1, 'work': 8, 'home': 1},
      );
      expect(hits, hasLength(2));
      expect(
        hits,
        containsAll(<SuspiciousShrink>[
          (listKey: 'default', known: 20, next: 1),
          (listKey: 'home', known: 4, next: 1),
        ]),
      );
    });

    test('a list missing from the publish set is not checked', () {
      // Only the lists actually being sent are compared; a list that is
      // skipped as unchanged is not part of publishCounts.
      final hits = findSuspiciousListShrinks(
        knownCounts: const {'default': 20, 'work': 8},
        publishCounts: const {'default': 20},
      );
      expect(hits, isEmpty);
    });
  });
}
