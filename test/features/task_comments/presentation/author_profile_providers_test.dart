import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/presentation/providers/author_profile_providers.dart';

void main() {
  group('sanitizeAuthorDisplayName', () {
    test('null input returns null', () {
      expect(sanitizeAuthorDisplayName(null), isNull);
    });

    test('empty string returns null', () {
      expect(sanitizeAuthorDisplayName(''), isNull);
    });

    test(
      'strips newlines, tabs and carriage returns, collapsing whitespace',
      () {
        expect(sanitizeAuthorDisplayName('Alice\n\t\r Smith'), 'Alice Smith');
      },
    );

    test('strips Unicode bidi override/isolate control characters', () {
      // U+202E (RLO) + reversed-looking text + U+202C (PDF), then a
      // U+2066/U+2069 (LRI/PDI) isolate pair — all stripped as bidi control.
      // ignore: text_direction_code_point_in_literal
      const withBidi = 'Alice‮civil‬⁦Bob⁩';
      expect(sanitizeAuthorDisplayName(withBidi), 'AlicecivilBob');
    });

    test('zero-width-only input sanitizes to null', () {
      // U+200B, U+200C, U+200D, U+FEFF only.
      const zeroWidthOnly = '​‌‍﻿';
      expect(sanitizeAuthorDisplayName(zeroWidthOnly), isNull);
    });

    test('zero-width characters are stripped from a real name', () {
      const withZeroWidth = 'A​lice‌ ‍Smith﻿';
      expect(sanitizeAuthorDisplayName(withZeroWidth), 'Alice Smith');
    });

    test('truncates long names to the display cutoff', () {
      final longName = 'A' * 256;
      final result = sanitizeAuthorDisplayName(longName);
      expect(result, isNotNull);
      expect(result!.length, 24);
      expect(result, 'A' * 24);
    });

    test('collapses runs of whitespace to a single space', () {
      expect(sanitizeAuthorDisplayName('Alice     Smith'), 'Alice Smith');
    });

    test('leaves an ordinary short name untouched', () {
      expect(sanitizeAuthorDisplayName('Alice'), 'Alice');
    });
  });
}
