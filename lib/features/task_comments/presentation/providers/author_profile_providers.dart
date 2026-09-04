import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bridge_generated.dart/api.dart' as rust_api;

/// Cutoff for the sanitized display name shown next to the shortened npub.
/// The Rust side allows up to 256 chars in kind:0; the UI only needs a
/// glance-length label.
const int _maxDisplayNameLength = 24;

/// Author attribution for one comment bubble: a shortened npub (always
/// present) plus an optional sanitized kind:0 display name.
class AuthorLabel {
  const AuthorLabel({required this.shortNpub, this.displayName});

  /// Shortened npub, e.g. `npub1abcdef…xyz123`. Always present so the label
  /// still renders when no kind:0 profile exists.
  final String shortNpub;

  /// Sanitized kind:0 display/name, or null when no profile was found.
  final String? displayName;
}

/// Cache of pubkey (hex) -> [AuthorLabel] for comment author attribution.
///
/// Shared-list comments are self-asserted (every member signs with the same
/// group key), so a display name is not proof of identity — the shortened
/// npub is always kept alongside it as the harder-to-spoof fallback.
final NotifierProvider<AuthorLabelsNotifier, Map<String, AuthorLabel>>
authorLabelsProvider =
    NotifierProvider<AuthorLabelsNotifier, Map<String, AuthorLabel>>(
      AuthorLabelsNotifier.new,
    );

class AuthorLabelsNotifier extends Notifier<Map<String, AuthorLabel>> {
  /// How long to wait before retrying a pubkey whose relay query threw
  /// (transient failure), so a flaky relay does not turn into a per-frame
  /// retry storm while still recovering within the same session.
  static const Duration _retryCooldown = Duration(seconds: 60);

  final Set<String> _pending = {};
  final Map<String, DateTime> _failedAt = {};

  @override
  Map<String, AuthorLabel> build() => const {};

  /// Loads labels for any [pubkeyHexes] that are neither cached, already in
  /// flight, nor in a post-failure cooldown, batching all of them into a
  /// single relay query. Safe to call repeatedly (e.g. on every build) —
  /// already-known or in-flight pubkeys are skipped.
  void ensureLoaded(List<String> pubkeyHexes) {
    final now = DateTime.now();
    final toFetch = <String>[];
    for (final hex in pubkeyHexes) {
      if (state.containsKey(hex) || _pending.contains(hex)) {
        continue;
      }
      final failedAt = _failedAt[hex];
      if (failedAt != null && now.difference(failedAt) < _retryCooldown) {
        continue;
      }
      toFetch.add(hex);
    }
    if (toFetch.isEmpty) {
      return;
    }
    _pending.addAll(toFetch);
    unawaited(_load(toFetch));
  }

  Future<void> _load(List<String> pubkeyHexes) async {
    try {
      final shortNpubs = <String, String>{};
      await Future.wait(
        pubkeyHexes.map((hex) async {
          var shortNpub = _shortenIdentifier(hex);
          try {
            final npub = await rust_api.hexToNpub(hex: hex);
            shortNpub = _shortenIdentifier(npub);
          } on Exception {
            // Keep the hex-derived fallback.
          }
          shortNpubs[hex] = shortNpub;
        }),
      );

      List<rust_api.ContactProfile> profiles;
      try {
        profiles = await rust_api.fetchProfilesMetadata(
          pubkeyHexes: pubkeyHexes,
        );
      } on Exception {
        // The relay query itself failed — this tells us nothing about
        // whether a kind:0 exists, so don't cache these as "no profile"
        // (that would be permanent, since ensureLoaded skips cached keys).
        // Record a short cooldown instead so a flaky relay gets retried on
        // a later call rather than never, but also not every frame.
        final now = DateTime.now();
        for (final hex in pubkeyHexes) {
          _failedAt[hex] = now;
        }
        return;
      }

      // The query succeeded, so any pubkey missing from the results really
      // has no kind:0 — that is the one case safe to cache permanently.
      final profileByHex = {for (final p in profiles) p.pubkeyHex: p};
      final labels = <String, AuthorLabel>{
        for (final hex in pubkeyHexes)
          hex: AuthorLabel(
            shortNpub: shortNpubs[hex]!,
            displayName: profileByHex[hex] == null
                ? null
                : _sanitizeDisplayName(
                    profileByHex[hex]!.displayName ??
                        profileByHex[hex]!.name,
                  ),
          ),
      };
      _failedAt.removeWhere((hex, _) => labels.containsKey(hex));
      state = {...state, ...labels};
    } finally {
      _pending.removeAll(pubkeyHexes);
    }
  }
}

/// Shortens a hex pubkey or npub to `<first 12>…<last 6>` for display.
String _shortenIdentifier(String value) {
  return value.length > 20
      ? '${value.substring(0, 12)}…${value.substring(value.length - 6)}'
      : value;
}

/// Sanitizes an untrusted kind:0 display/name field for use as a comment
/// author label: strips control, bidi-override and zero-width characters,
/// collapses whitespace, and truncates to a glance-length cutoff. Returns
/// null if nothing meaningful remains.
String? sanitizeAuthorDisplayName(String? raw) {
  return _sanitizeDisplayName(raw);
}

String? _sanitizeDisplayName(String? raw) {
  if (raw == null) {
    return null;
  }

  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (_isStrippedRune(rune)) {
      continue;
    }
    buffer.writeCharCode(rune);
  }

  var cleaned = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) {
    return null;
  }

  // U+200C (ZWNJ) and U+200D (ZWJ) are kept below (they combine emoji and
  // carry orthographic meaning in several scripts), but a name made of only
  // joiners and spaces still renders as nothing and passes the empty check
  // above — treat that the same as an empty name.
  const zeroWidthJoiner = 0x200D;
  const zeroWidthNonJoiner = 0x200C;
  final isOnlyInvisibleGlue = cleaned.runes.every(
    (rune) =>
        rune == zeroWidthJoiner ||
        rune == zeroWidthNonJoiner ||
        rune == 0x20,
  );
  if (isOnlyInvisibleGlue) {
    return null;
  }

  final runes = cleaned.runes.toList();
  if (runes.length > _maxDisplayNameLength) {
    cleaned = String.fromCharCodes(runes.take(_maxDisplayNameLength));
  }
  return cleaned;
}

/// Whether [rune] should be stripped from an untrusted display name: C0/C1
/// control characters (including newline/tab/CR), Unicode bidi
/// override/isolate/mark controls (which can visually reorder text to spoof
/// another author), and invisible formatting characters (which can hide
/// payloads inside an apparently-empty or apparently-matching name).
///
/// U+200C (ZWNJ) and U+200D (ZWJ) are deliberately NOT included: they
/// compose emoji sequences and carry orthographic meaning in several scripts
/// (Devanagari, Bengali, Arabic), and — unlike the bidi controls above —
/// they cannot reorder text, so they are not a spoofing vector. A name made
/// of only those plus whitespace is still rejected separately, in
/// [_sanitizeDisplayName].
bool _isStrippedRune(int rune) {
  if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
    return true;
  }
  // Bidi override (LRE/RLE/PDF/LRO/RLO), isolate (LRI/RLI/FSI/PDI) and mark
  // (ALM) control characters.
  if (rune >= 0x202A && rune <= 0x202E) {
    return true;
  }
  if (rune >= 0x2066 && rune <= 0x2069) {
    return true;
  }
  if (rune == 0x200E || rune == 0x200F || rune == 0x061C) {
    return true;
  }
  // Zero-width / invisible formatting characters, excluding ZWNJ/ZWJ (see
  // the doc comment above): ZWSP, word joiner + invisible math operators,
  // Mongolian vowel separator, deprecated interlinear annotation controls,
  // and the BOM/ZWNBSP.
  if (rune == 0x200B) {
    return true;
  }
  if (rune >= 0x2060 && rune <= 0x2064) {
    return true;
  }
  if (rune == 0x180E) {
    return true;
  }
  if (rune >= 0xFFF9 && rune <= 0xFFFB) {
    return true;
  }
  if (rune == 0xFEFF) {
    return true;
  }
  return false;
}
