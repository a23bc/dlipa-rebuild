# Install error 181: the embedded framework was malformed

    DLiPA-fe69facd.ipa    91.54 MB
    sha256  138e325537a04ef923cc6410b1ccdfc93a837bad09ec8da80464a8b61e366d63
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/38886847819

## Ruling out the stale copy

This attempt installed `DLiPA-8e892eac.ipa`, the digest-named file from the
previous run, and the log is identical apart from timestamps. So the build
itself is the cause, and the cause is in the registration dictionary:

    ApplicationType = System

`System` is what MobileInstallation assigns when a bundle contains something
it considers malformed. Signing was fine throughout - ldid returned 0 twice
and the CoreTrust bypass applied to both binaries.

## The cause

The app embeds `SapBridge.framework`, and gomobile writes its Info.plist as:

    CFBundleIdentifier  SapBridge        <- not reverse-DNS
    MinimumOSVersion   100.0            <- not a real version

A bundle identifier has to be reverse-DNS. `SapBridge` is not, and 100.0 is
not a version iOS recognises. The original DLiPA bundles no frameworks at all,
which is why it never hit this; every prior fix was aimed at the app's own
Info.plist and left the nested one untouched.

## The fix, verified in the shipped artifact

Rewritten before packaging, then read back out of the IPA:

    CFBundleIdentifier   com.a23bc.dliparebuild.SapBridge
    MinimumOSVersion    15.0
    CFBundlePackageType FMWK
    reverse-DNS form    YES

The step fails loudly if the framework is not where the build puts it, rather
than skipping silently - which is how this stayed hidden for four attempts.

## Everything else still holds

    Assets.car, both icons, PkgInfo   byte-identical to the original
    app Info.plist install-critical keys   9/9 identical
    executable permissions           755
    bundle id                        com.a23bc.dliparebuild
    minimum iOS                      15.0

## If it still fails

This is the last malformed thing in the bundle that I can find. If error 181
persists with this file, the remaining suspect is the framework being
embedded at all: the original is a single binary, and the fallback would be
to link the bridge statically into the app instead of embedding it. That is a
real change rather than a metadata fix, so I would rather know the result of
this build first.
