# Install: Assets.car was missing

    DLiPA-unsigned.ipa    91.54 MB
    sha256  8dbff54870be37d242df23765059f77f99e2b808a5ecf3390e5aee11e64ffac7
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/38883733600

## First: this attempt was identical to the last one

The two logs you sent are byte-for-byte the same apart from timestamps, PIDs
and UUIDs. Same error 181, same `ApplicationType = System`, same failing
registration dictionary. So the scene-manifest fix either was not in the IPA
you tested, or it was not the remaining cause. Either way something was still
wrong.

## The cause: no Assets.car

`Failed to add app to icon cache` is what the icon cache service says when it
has no compiled asset catalog to read. The original bundle ships `Assets.car`
at 196 KB; ours had none, because deleting the asset catalog was what got the
Xcode build past actool on the runner.

That was fixing the build by removing a file the runtime needs. The icon cache
step runs after signing has already succeeded, which is why ldid and the
CoreTrust bypass both looked clean right up to the failure.

The original file is carried over, the same way the icons and the localisation
strings were.

## Verified against the original bundle

Comparing the shipped app bundle with the one that installs:

    AppIcon60x60@2x.png      IDENTICAL
    AppIcon76x76@2x~ipad.png IDENTICAL
    Assets.car               IDENTICAL
    PkgInfo                  IDENTICAL

Still not carried over, because our code does not use them and they are not
part of installing:

    blank_audio.mp3                 300 KB   kept a silent track alive for
                                             background playback
    localhost.direct.mobileconfig   profile the original served over its
                                             local install server
    localhost.direct.p12             its matching certificate

Say the word if you want those too; they belong to the local-install flow,
which this rebuild does not implement yet.

## Licensing

### Why MIT

The protocol code is a trimmed copy of ipatool, which is MIT. Keeping MIT means
the vendored files stay under the licence they were written under instead of
being relicensed, and avoids mixing terms across code that cannot be cleanly
separated from the rest. It is also permissive enough that nobody picking this
up is restricted, which suits a tool whose purpose is restoring a capability
the original lost.

### What MIT does not cover, now stated in the file

Most importantly: Unicorn is GPL v2 and is statically linked, so its terms
travel with the binary. MIT on this repo cannot override that. The Apple
binaries are Apple copyright, and the resources from the original DLiPA have no
licence at all.

### NOTICE filename

Renamed NOTICE.md to NOTICE, which is the name GitHub detects (it looks for
LICENSE, LICENCE, COPYING and NOTICE at the root). The .md extension was doing
nothing useful, so it is plain text with the markdown stripped.

    LICENSE   MIT, plus why, plus what it does not cover
    NOTICE    per-component attribution in plain text
