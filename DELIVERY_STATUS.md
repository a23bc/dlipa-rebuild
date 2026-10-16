# Install: you were testing a stale copy

    DLiPA-8e892eac.ipa    91.54 MB
    sha256  35dc23e7eeb8f503abcff85b8471bcb199a8dccc30c532c466cbee0ac09a5c49
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/38885472777

## The log gave it away

The install line reads:

    custom, ".../tmp/com.opa334.TrollStore-Inbox/DLiPA-unsigned (2).ipa"

The "(2)" is what Safari appends on a second download of the same file. Every
other line of the log, all 85 of them after normalising timestamps, PIDs and
UUIDs, was identical to the previous attempt. Same error 181, same
ApplicationType = System.

The IPA with Assets.car was built and committed at 09:47; your install was at
18:03. What got installed was very likely an old download rather than the new
build.

## What changed so this cannot recur

The artifact is now named with a short digest of the binary: DLiPA-8e892eac.ipa.
Every build has a different name, so a stale download is visible at a glance.
The package, report, artifact and release steps all use that name.

Before the next attempt, delete the old DLiPA-unsigned*.ipa from Files and from
the TrollStore inbox, then use the file named DLiPA-8e892eac.

## The build itself is verified

Every check run against the shipped artifact passes:

    Assets.car                  IDENTICAL to the original
    AppIcon60x60@2x.png         IDENTICAL
    AppIcon76x76@2x~ipad.png    IDENTICAL
    PkgInfo                     IDENTICAL
    Info.plist install-critical keys   9/9 IDENTICAL
    executable permission       755, correct
    bundle id                   com.a23bc.dliparebuild
    minimum iOS                 15.0

## Licensing, as advised

Agreed with the reasoning: a NOTICE file that only repeated LICENSE was adding
noise, and MIT does not require one. The parts that were not duplication are
the third-party attributions, and those now have a name that says what they
are.

    LICENSE                   MIT text, plus a scope note on what it does not cover
    THIRD_PARTY_LICENSES.md   per-component attribution, markdown so it renders

NOTICE is gone. LICENSE keeps one paragraph on why MIT, because a reader will
actually ask, and one saying Unicorn is GPL v2 and statically linked so its
terms travel with the binary - the one thing MIT on this repo cannot override.
README links both.
