# Delivery: DLiPA IPA built

**The IPA is built and verified.**

    DLiPA-unsigned.ipa    97.37 MB    arm64
    sha256  9bd3f55fe92254e6a2e7ffca2ab753b038182c7067acbc0404dbcd09990f2673

Run: https://github.com/a23bc/dlipa-rebuild/actions/runs/38876350947

Both jobs green:

    Build SAP bridge for iOS      2m33s  pass
    Build unsigned DLiPA app      1m11s  pass

## What is inside

    Payload/DLiPA.app/DLiPA                    10.38 MB  arm64 Mach-O
    Payload/DLiPA.app/Frameworks/SapBridge.framework
    Payload/DLiPA.app/Resources/SapAssets/      119 MB
        CoreFP              94,842,464
        AppleMediaServices  14,813,888
        commerce             8,092,640
        CoreFP.icxs          7,365,344
    Payload/DLiPA.app/icon-152.png
    14 x Localizable.strings

Unicorn is statically linked into the main binary, which is why it is
10 MB rather than the few hundred KB the Go code alone would produce.

## Install it

The payload is unsigned on purpose. Sign it with a free Apple ID:

- **AltStore** - open the IPA from the My Apps tab
- **Sideloadly** - drag the IPA in and sign in

Free Apple IDs get a 7-day certificate, so re-sign weekly. A paid developer
account lasts a year.

## Verified locally

    go build = 0    go vet = 0    go test = ok    gofmt = clean
    zip opens, Payload/ present, binary magic CF FA ED FE (arm64)
    all four SAP assets present at the path the app loads them from
    all four asset sizes match the pinned digests

## Bugs found by this run

| Symptom | Cause |
|---|---|
| gomobile builds were failing on the simulator slice | the target was `ios`, which builds every variant; `ios/arm64` builds only the device |
| `New` and `KBSync` missing from the framework | gobind silently skips functions with `uint32`/`uint64`; changed to `int32` and `string` |
| Swift calls rejected as extraneous labels | gobind exports package functions as C functions, which carry no argument labels in Swift |
| `uc_*` undefined in the app link | picked `libunicorn-static.a`, which is only the common target; the full library is `libunicorn.a` |
| ibtool and actool failures | the runner ships the iOS 18 SDK without the installed platform; both tools probe for runtimes |
| package-ipa.sh died before zipping | `$ROOT` was never set and `$OLDPWD` is unreliable inside the subshell |

The last one is worth noting: the app itself built successfully two runs
before the IPA existed, so the packaging script was the only thing standing
between a green pipeline and a deliverable.
