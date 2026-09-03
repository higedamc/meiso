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
      const withBidi = 'Alice\u{202E}civil\u{202C}\u{2066}Bob\u{2069}';
      expect(sanitizeAuthorDisplayName(withBidi), 'AlicecivilBob');
    });

    test('strips U+061C (Arabic Letter Mark), a bidi control character', () {
      expect(sanitizeAuthorDisplayName('Ali\u{061C}ce'), 'Alice');
    });

    test('strips U+2060 (word joiner), an invisible formatting character', () {
      const wordJoinerOnly = '\u{2060}\u{2060}';
      expect(sanitizeAuthorDisplayName(wordJoinerOnly), isNull);
    });

    test('zero-width-only input (ZWSP/ZWNJ/ZWJ/BOM) sanitizes to null', () {
      const zeroWidthOnly = '\u{200B}\u{200C}\u{200D}\u{FEFF}';
      expect(sanitizeAuthorDisplayName(zeroWidthOnly), isNull);
    });

    test('ZWNJ/ZWJ-only input (no other invisible chars) sanitizes to null', () {
      const joinersOnly = '\u{200C}\u{200D}';
      expect(sanitizeAuthorDisplayName(joinersOnly), isNull);
    });

    test('ZWSP and BOM are stripped from a real name', () {
      const withZeroWidth = 'A\u{200B}lice \u{FEFF}Smith';
      expect(sanitizeAuthorDisplayName(withZeroWidth), 'Alice Smith');
    });

    test(
      'ZWJ is preserved so an emoji sequence stays combined (not split)',
      () {
        // U+1F468 (man) + ZWJ + U+1F469 (woman) — a "couple" emoji sequence.
        // If ZWJ were stripped this would decode as two separate emoji.
        const familyEmoji = '\u{1F468}\u{200D}\u{1F469}';
        final result = sanitizeAuthorDisplayName(familyEmoji);
        expect(result, isNotNull);
        expect(result!.runes.length, 3);
        expect(result, familyEmoji);
      },
    );

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
