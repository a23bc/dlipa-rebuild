#!/bin/sh
# Package an unsigned .app as an installable .ipa.
#
# The IPA format is a zip whose root contains Payload/. AltStore and
# Sideloadly accept an unsigned payload and sign it with the user Apple ID.
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

# Strip any accidental code signature the build left behind; a stale
# signature breaks re-signing on the user side.
rm -rf "$WORK/Payload"/*.app/_CodeSignature 2>/dev/null || true

# iTunesArtwork is optional but some tools look for it.
if [ -f "$APP/iTunesArtwork" ]; then
  cp "$APP/iTunesArtwork" "$WORK/"
fi

# $OLDPWD is not reliable inside a subshell, so resolve the output path
# before changing directory.
case $OUT in
  /*) OUT_ABS=$OUT ;;
  *) OUT_ABS=$(pwd)/$OUT ;;
esac

( cd "$WORK" && zip -qry "$OUT_ABS" . )

echo "==> wrote $OUT_ABS"
ls -la "$OUT_ABS"
shasum -a 256 "$OUT_ABS"
