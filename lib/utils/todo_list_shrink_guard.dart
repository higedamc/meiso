/// Shrink guard for kind 30001 publishes.
///
/// Kind 30001 is a replaceable event carrying a whole list, so publishing a
/// list from an incomplete local state silently deletes every task the relay
/// copy had and the local copy lacks. The guard compares the number of todos
/// about to be published per list with the last count that was confirmed on
/// the relay (recorded after a successful publish or fetch) and refuses the
/// publish when a list shrank to less than half.
///
/// Pure functions so the policy can be unit-tested without a provider.
library;

/// Minimum known count for the guard to apply. Lists this small shrink for
/// ordinary reasons (finishing a two-item list) and would only produce
/// false positives.
const int shrinkGuardMinKnownCount = 3;

/// Fraction of the known count below which a publish is refused.
const double shrinkGuardThreshold = 0.5;

/// A refused publish: the list, its last confirmed count and the count that
/// was about to be sent.
typedef SuspiciousShrink = ({String listKey, int known, int next});

/// Whether publishing [next] todos for a list last known to hold [known]
/// todos should be refused.
bool isSuspiciousListShrink({required int known, required int next}) {
  if (known < shrinkGuardMinKnownCount) return false;
  if (next >= known) return false;
  return next < (known * shrinkGuardThreshold).ceil();
}

/// Every list in [publishCounts] whose count is a suspicious shrink against
/// [knownCounts]. Lists without a known count are never suspicious: there is
/// nothing to compare against.
List<SuspiciousShrink> findSuspiciousListShrinks({
  required Map<String, int> knownCounts,
  required Map<String, int> publishCounts,
}) {
  final result = <SuspiciousShrink>[];
  for (final entry in publishCounts.entries) {
    final known = knownCounts[entry.key];
    if (known == null) continue;
    if (isSuspiciousListShrink(known: known, next: entry.value)) {
      result.add((listKey: entry.key, known: known, next: entry.value));
    }
  }
  return result;
}
