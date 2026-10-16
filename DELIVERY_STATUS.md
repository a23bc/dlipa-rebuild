# Install error 181: found by comparing against the apps that work

    DLiPA-7a59af5a.ipa    85.32 MB   (was 91.53)
    sha256  f3685096ee8286ddd5973e6e2c92028a303b1104543b9d243ae565abd3a6f9ca
    run     https://github.com/a23bc/dlipa-rebuild/actions/runs/38899947723

## The comparison that cracked it

Three apps of yours that install, and what each one does:

| App | Build action | Signing |
|---|---|---|
| ipa-downloader | `build` | none, `CODE_SIGNING_ALLOWED=NO` |
| PNG2HEIF | `archive` | none, `CODE_SIGNING_ALLOWED=NO` |
| dlipa-next | tests only | n/a |

**ipa-downloader uses the same flags we do and installs with no signature at
all.** That ruled out the LC_CODE_SIGNATURE theory I had been chasing for three
attempts. The `codesign` and `ldid` steps are gone.

## What was actually wrong

The bundle root contained `CoreFP.icxs`, 7 MB, in addition to the correct copy
in `Resources/SapAssets/`. The new step prints the bundle root before and after,
and named it directly:

    ==> bundle root before cleanup
    app/build/.../DLiPA.app/CoreFP.icxs

It came from an early attempt to satisfy the `./../CoreFP.icxs` path in
`shim_platform.go`. That path is internal to the emulated guest - it is the path
the CoreFP process opens inside the virtual machine, never a path on the iOS
filesystem. The Go loader reads all four binaries from the directory
`BundleDir` names, which the app sets to `Resources/SapAssets`, and feeds them
to the guest from memory. The root copy was dead weight that MobileInstallation
validated and rejected.

## Bundle root now

    AppIcon60x60@2x.png
    AppIcon76x76@2x~ipad.png
    Assets.car
    DLiPA
    Info.plist
    PkgInfo

The same file list as the original, and the same shape as ipa-downloader. The
IPA dropped from 91.53 to 85.32 MB, which is the duplicate going away.

The four assets are intact in `Resources/SapAssets/`: CoreFP 90.45 MB,
AppleMediaServices 14.13 MB, CoreFP.icxs 7.02 MB, commerce 7.72 MB.

## Also fixed

`package-ipa.sh` was failing the build on a `_CodeSignature` check I had added for
the signing theory. Removed, along with the signing references in the README.

One workflow breakage of my own along the way: removing a step left the next
one indented 12 spaces instead of 6, which GitHub rejected before starting any
job. Worth noting because the symptom, a run failing in 0 seconds, looks
nothing like a real failure.
