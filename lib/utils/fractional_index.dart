/// LexoRank 風の fractional index（並行 reorder の衝突を緩和）
class FractionalIndex {
  FractionalIndex._();

  static const String initial = '0|hzzzz';

  /// [before] と [after] の間に挿入する index を生成する。
  /// どちらか一方のみ指定可。
  static String between({String? before, String? after}) {
    if (before == null && after == null) {
      return initial;
    }
    if (before == null) {
      return _decrement(after!);
    }
    if (after == null) {
      return _increment(before);
    }
    return _midpoint(before, after);
  }

  static String _increment(String value) {
    final parts = value.split('|');
    if (parts.length != 2) {
      return '${value}a';
    }
    final head = parts[0];
    final tail = parts[1];
    if (tail.isEmpty) {
      return '$head|a';
    }
    final last = tail.codeUnitAt(tail.length - 1);
    if (last < 0x7a) {
      return '$head|${tail.substring(0, tail.length - 1)}${String.fromCharCode(last + 1)}';
    }
    return '$head|${tail}a';
  }

  static String _decrement(String value) {
    final parts = value.split('|');
    if (parts.length != 2) {
      return '0|${value}';
    }
    final head = parts[0];
    final tail = parts[1];
    if (tail.isEmpty) {
      return '$head|y';
    }
    final last = tail.codeUnitAt(tail.length - 1);
    if (last > 0x61) {
      return '$head|${tail.substring(0, tail.length - 1)}${String.fromCharCode(last - 1)}';
    }
    return '$head|${tail}0';
  }

  static String _midpoint(String before, String after) {
    if (before.compareTo(after) >= 0) {
      return _increment(before);
    }
    final bParts = before.split('|');
    final aParts = after.split('|');
    if (bParts.length == 2 && aParts.length == 2 && bParts[0] == aParts[0]) {
      final head = bParts[0];
      final bTail = bParts[1];
      final aTail = aParts[1];
      if (bTail.length < aTail.length) {
        final prefix = bTail.isEmpty ? '' : bTail.substring(0, bTail.length);
        return '$head|${prefix}m';
      }
    }
    return _increment(before);
  }
}
