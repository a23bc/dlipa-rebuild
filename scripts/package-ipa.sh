#!/bin/sh
# Package an unsigned .app as an installable .ipa.
#
# The IPA format is just a zip whose root contains Payload/. AltStore and
# Sideloadly accept an unsigned payload and sign it with the user's Apple ID.
set -eu

APP=${1:?usage: package-ipa.sh <path-to-.app> <output.ipa>}
OUT=${2:?usage: package-ipa.sh <path-to-.app> <output.ipa>}

if [ ! -d "$APP" ]; then
  echo "::error::$APP is not a directory" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

mkdir -p "$WORK/Payload"
cp -R "$APP" "$WORK/Payload/"

# Strip any accidental code signature left by the build; a stale signature
# breaks re-signing on the user side.
rm -rf "$WORK/Payload"/*.app/_CodeSignature || true

# iTunesArtwork is optional but some tools look for it.
if [ -f "$ROOT/Resources/iTunesArtwork" ]; then
  cp "$ROOT/Resources/iTunesArtwork" "$WORK/"
fi

( cd "$WORK" && zip -qry "$OLDPWD/$OUT" . )

echo "==> wrote $OUT"
ls -la "$OUT"
shasum -a 256 "$OUT"
