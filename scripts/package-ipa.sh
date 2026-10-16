#!/bin/sh
# Package an unsigned .app as an installable .ipa.
#
# The IPA format is a zip whose root contains Payload/. AltStore, Sideloadly and
# TrollStore all accept an unsigned payload; the signature is applied on the
# device when the user signs in.
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

# No signature is added or removed. The apps that install under TrollStore are
# packaged exactly this way: build unsigned, zip Payload. The signature is
# applied on the device.
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
