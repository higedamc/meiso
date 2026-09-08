import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/infrastructure/shared_task_comment_filter.dart';

void main() {
  group('buildSharedTaskCommentFilter', () {
    test('filters on kind:35002 and every group npub', () {
      final filter = buildSharedTaskCommentFilter(
        groupNpubHexes: ['npub-a', 'npub-b'],
      );
      expect(filter, isNotNull);
      expect(filter!['kinds'], [taskCommentKind]);
      expect(filter['authors'], ['npub-a', 'npub-b']);
      expect(filter.containsKey('since'), isFalse);
    });

    test('includes since when a resume point is given', () {
      final filter = buildSharedTaskCommentFilter(
        groupNpubHexes: ['npub-a'],
        sinceUnixSeconds: 1788514631,
      );
      expect(filter!['since'], 1788514631);
    });

    test('returns null for an empty group list (matches nothing)', () {
      expect(
        buildSharedTaskCommentFilter(groupNpubHexes: const []),
        isNull,
      );
    });
  });
}
