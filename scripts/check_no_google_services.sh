#!/usr/bin/env bash
# Acceptance check for meiso issue #245: the shipped APK must contain no
# Google Play Services / ML Kit / Firebase / Google datatransport code.
#
# Usage: scripts/check_no_google_services.sh <path/to/app.apk>
# Exit 0 when every gating counter is zero, 1 otherwise, 2 on usage/tool errors.
#
# The zapstore relay enricher (zapstore/steroid) decides the "Google Play
# Services" fact from the classes *defined* in the APK's DEX files, not from
# the manifest or from string literals. The gating checks therefore use the
# same semantics:
#   1. DEX defined classes (apkanalyzer dex packages --defined-only) under
#      com.google.android.gms / com.google.mlkit / com.google.firebase /
#      com.google.android.datatransport must all be 0.
#   2. No lib/*/libbarhopper* native library (Google's barcode engine).
# Informational only (not gating; string literals can produce false hits):
#   3. AndroidManifest references to the same four namespaces.
#   4. `strings classes*.dex` hits for the same four namespaces.
#
# Deliberately NOT matched: com.google.common (Guava, pulled in by CameraX) and
# com.google.gson / com.google.crypto.tink. steroid's googlePlay() rule does not
# match them either, so a broad com.google.* grep would be a false red.
# pipefail: a partial apkanalyzer dump must fail the gate, not slip past awk.
set -u -o pipefail

apk="${1:-}"
if [ -z "$apk" ] || [ ! -f "$apk" ]; then
  echo "usage: $0 <app.apk>" >&2
  exit 2
fi

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
apkanalyzer="${APKANALYZER:-$sdk/cmdline-tools/latest/bin/apkanalyzer}"
if [ ! -x "$apkanalyzer" ]; then
  echo "apkanalyzer not found at $apkanalyzer; set APKANALYZER=/path/to/apkanalyzer" >&2
  exit 2
fi
aapt2="${AAPT2:-}"
if [ -z "$aapt2" ]; then
  aapt2="$(ls -1 "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n 1)"
fi
if [ -z "$aapt2" ] || [ ! -x "$aapt2" ]; then
  echo "aapt2 not found; set AAPT2=/path/to/aapt2" >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# grep -c prints 0 and exits 1 on no match; "|| true" keeps the single "0".
count() { grep -c -- "$1" "$2" || true; }

# --- 1. DEX defined classes (gating) --------------------------------------
classes="$work/classes.txt"
if ! "$apkanalyzer" dex packages --defined-only "$apk" 2>"$work/apkanalyzer.err" \
    | awk '$1=="C" {print $NF}' > "$classes"; then
  echo "apkanalyzer failed:" >&2
  cat "$work/apkanalyzer.err" >&2
  exit 2
fi
total_classes="$(wc -l < "$classes" | tr -d ' ')"
if [ "$total_classes" -eq 0 ]; then
  echo "apkanalyzer returned no defined classes; refusing to pass on empty input" >&2
  cat "$work/apkanalyzer.err" >&2
  exit 2
fi
c_gms="$(count '^com\.google\.android\.gms\.' "$classes")"
c_mlkit="$(count '^com\.google\.mlkit\.' "$classes")"
c_firebase="$(count '^com\.google\.firebase\.' "$classes")"
c_dt="$(count '^com\.google\.android\.datatransport\.' "$classes")"
c_guava="$(count '^com\.google\.common\.' "$classes")"
c_camerax="$(count '^androidx\.camera\.' "$classes")"

# --- 2. Native libraries (gating) -----------------------------------------
n_barhopper="$(unzip -Z1 "$apk" | grep -c 'libbarhopper' || true)"

# --- 3. Manifest (informational) ------------------------------------------
manifest="$work/manifest.txt"
if ! "$aapt2" dump xmltree --file AndroidManifest.xml "$apk" > "$manifest" 2>"$work/aapt2.err"; then
  echo "aapt2 dump failed:" >&2
  cat "$work/aapt2.err" >&2
  exit 2
fi
m_gms="$(count 'com.google.android.gms' "$manifest")"
m_mlkit="$(count 'com.google.mlkit' "$manifest")"
m_firebase="$(count 'com.google.firebase' "$manifest")"
m_dt="$(count 'com.google.android.datatransport' "$manifest")"

# --- 4. DEX string literals (informational) -------------------------------
unzip -q -o "$apk" 'classes*.dex' -d "$work/dex" 2>/dev/null || true
s_gms=0; s_mlkit=0; s_firebase=0; s_dt=0
for dex in "$work"/dex/classes*.dex; do
  [ -f "$dex" ] || continue
  strings "$dex" > "$work/strings.txt"
  s_gms=$((s_gms + $(count 'com/google/android/gms' "$work/strings.txt")))
  s_mlkit=$((s_mlkit + $(count 'com/google/mlkit' "$work/strings.txt")))
  s_firebase=$((s_firebase + $(count 'com/google/firebase' "$work/strings.txt")))
  s_dt=$((s_dt + $(count 'com/google/android/datatransport' "$work/strings.txt")))
done

size="$(wc -c < "$apk" | tr -d ' ')"
sha="$(shasum -a 256 "$apk" | cut -d' ' -f1)"

echo "apk:        $apk"
echo "size_bytes: $size"
echo "sha256:     $sha"
echo "--- gating: DEX defined classes (total $total_classes) ---"
echo "com.google.android.gms:            $c_gms"
echo "com.google.mlkit:                  $c_mlkit"
echo "com.google.firebase:               $c_firebase"
echo "com.google.android.datatransport:  $c_dt"
echo "--- gating: native ---"
echo "lib libbarhopper entries:          $n_barhopper"
echo "--- informational: allowed neighbours ---"
echo "com.google.common (Guava):         $c_guava"
echo "androidx.camera (CameraX):         $c_camerax"
echo "--- informational: manifest references ---"
echo "com.google.android.gms:            $m_gms"
echo "com.google.mlkit:                  $m_mlkit"
echo "com.google.firebase:               $m_firebase"
echo "com.google.android.datatransport:  $m_dt"
echo "--- informational: DEX string literals ---"
echo "com/google/android/gms:            $s_gms"
echo "com/google/mlkit:                  $s_mlkit"
echo "com/google/firebase:               $s_firebase"
echo "com/google/android/datatransport:  $s_dt"

gating=$((c_gms + c_mlkit + c_firebase + c_dt + n_barhopper))
if [ "$gating" -eq 0 ]; then
  echo "RESULT: PASS (no Google Play Services / ML Kit / Firebase / datatransport classes or libbarhopper)"
  exit 0
fi
echo "RESULT: FAIL (gating hits: $gating)"
exit 1
