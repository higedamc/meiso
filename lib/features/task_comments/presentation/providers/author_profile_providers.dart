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
  final Set<String> _pending = {};

  @override
  Map<String, AuthorLabel> build() => const {};

  /// Loads labels for any [pubkeyHexes] that are neither cached nor already
  /// in flight, batching all of them into a single relay query. Safe to call
  /// repeatedly (e.g. on every build) — already-known or in-flight pubkeys
  /// are skipped.
  void ensureLoaded(List<String> pubkeyHexes) {
    final toFetch = <String>[];
    for (final hex in pubkeyHexes) {
      if (state.containsKey(hex) || _pending.contains(hex)) {
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
      final labels = <String, AuthorLabel>{};

      await Future.wait(
        pubkeyHexes.map((hex) async {
          var shortNpub = _shortenIdentifier(hex);
          try {
            final npub = await rust_api.hexToNpub(hex: hex);
            shortNpub = _shortenIdentifier(npub);
          } on Exception {
            // Keep the hex-derived fallback.
          }
          labels[hex] = AuthorLabel(shortNpub: shortNpub);
        }),
      );

      var profiles = <rust_api.ContactProfile>[];
      try {
        profiles = await rust_api.fetchProfilesMetadata(
          pubkeyHexes: pubkeyHexes,
        );
      } on Exception {
        // No profiles this round; every pubkey still gets a shortNpub-only
        // entry below, which is cached as "no display name" rather than
        // retried forever.
      }
      for (final profile in profiles) {
        final existing = labels[profile.pubkeyHex];
        if (existing == null) {
          continue;
        }
        labels[profile.pubkeyHex] = AuthorLabel(
          shortNpub: existing.shortNpub,
          displayName: _sanitizeDisplayName(
            profile.displayName ?? profile.name,
          ),
        );
      }

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

  final runes = cleaned.runes.toList();
  if (runes.length > _maxDisplayNameLength) {
    cleaned = String.fromCharCodes(runes.take(_maxDisplayNameLength));
  }
  return cleaned;
}

/// Whether [rune] should be stripped from an untrusted display name: C0/C1
/// control characters (including newline/tab/CR), Unicode bidi override and
/// isolate controls (which can visually reorder text to spoof another
/// author), and zero-width characters (which can hide payloads inside an
/// apparently-empty or apparently-matching name).
bool _isStrippedRune(int rune) {
  if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
    return true;
  }
  if (rune >= 0x202A && rune <= 0x202E) {
    return true;
  }
  if (rune >= 0x2066 && rune <= 0x2069) {
    return true;
  }
  if (rune == 0x200E || rune == 0x200F) {
    return true;
  }
  if (rune >= 0x200B && rune <= 0x200D) {
    return true;
  }
  if (rune == 0xFEFF) {
    return true;
  }
  return false;
}
