#!/bin/sh
# Package an adhoc-signed .app as an installable .ipa.
#
# The IPA format is a zip whose root contains Payload/. AltStore, Sideloadly
# and TrollStore all accept an adhoc-signed payload; the user re-signs it with
# their own Apple ID.
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

# _CodeSignature is kept, not stripped. The adhoc signature is what gives the
# binary its LC_CODE_SIGNATURE load command, and removing it makes
# MobileInstallation type the bundle as System and fail registration with
# error 181.
if [ ! -d "$WORK/Payload"/*.app/_CodeSignature ]; then
  echo "::error::no _CodeSignature in $APP; the build must adhoc-sign" >&2
  exit 1
fi
echo "==> signature present:"
ls -la "$WORK/Payload"/*.app/_CodeSignature

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
